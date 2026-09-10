classdef FiaExplorer_V3 < matlab.apps.AppBase
%FIAEXPLORER_V3  Browse and export flow-injection mass spectrometry data.
%
%   Start the app by adding this folder and its subfolders to the MATLAB
%   path and running
%
%       FiaExplorer_V3
%
%   The three menus follow the three steps of the pipeline:
%
%       Load > Raw Data       import mzXML files, annotate, save a FIA file
%       Load > FIA File       reopen a saved FIA file
%       Annotation            re-annotate against a different database
%       Export > Fia-Data     write an Excel workbook
%       Export > To Workspace copy the open data set to the base workspace
%
%   about the data ++++++
%
%   The loaded data set is in the FiaData (an app property)
%   to get at it:
%
%     Export > To Workspace   puts a copy in the base workspace as
%                             "fia_data"
%
%     load(fiaFile)           every saved FIA file has one variable
%
%   How to use:
%   Clicking a row of the annotation table zooms the plot to the expected
%   mass of that ion and draws every sample in black, with the picked peaks
%   marked. Clicking a sample highlights it in red. The Zoom slider sets the
%   width of the mass window and now redraws immediately.
%
%   NOTE:
%   functions can be called and tested on their own:
%
%       params  = fia_default_params();
%       fiaData = import_raw_data(params);
%       fiaData = annotate_peaks(fiaData, params, 'db_ecmdb.mat');
%       export_fia_data(fiaData);
%
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

    % --------------------------------------------------------------------
    % UI components
    % --------------------------------------------------------------------
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        LoadMenu              matlab.ui.container.Menu
        LoadFiaFileMenu       matlab.ui.container.Menu
        LoadRawDataMenu       matlab.ui.container.Menu
        ExportMenu            matlab.ui.container.Menu
        ExportFiaDataMenu     matlab.ui.container.Menu
        ExportWorkspaceMenu   matlab.ui.container.Menu
        AnnotationMenu        matlab.ui.container.Menu
        SpectrumAxes          matlab.ui.control.UIAxes
        TabGroup              matlab.ui.container.TabGroup
        AnnotationTab         matlab.ui.container.Tab
        AnnotationTable       matlab.ui.control.Table
        SamplesTab            matlab.ui.container.Tab
        SampleTable           matlab.ui.control.Table
        PolaritySwitch        matlab.ui.control.Switch
        PolaritySwitchLabel   matlab.ui.control.Label
        ZoomSlider            matlab.ui.control.Slider
        ZoomSliderLabel       matlab.ui.control.Label
        TitleLabel            matlab.ui.control.Label
        LogoImage             matlab.ui.control.Image
        FiaFileCaptionLabel   matlab.ui.control.Label
        FiaFilePathLabel      matlab.ui.control.Label
        DatabaseCaptionLabel  matlab.ui.control.Label
        DatabaseNameLabel     matlab.ui.control.Label
    end

    % --------------------------------------------------------------------
    % Application state
    % --------------------------------------------------------------------
   
    properties (GetAccess = public, SetAccess = private)
        FiaData = []            % the 1-by-2 struct produced by IMPORT_RAW_DATA
    end

    properties (Access = private)
        FiaFilePath = ''        % full path of the FIA file currently open
        Params                  % configuration, see FIA_DEFAULT_PARAMS
        SelectedAnnotationRow = []   % row of annot the plot is showing
        SelectedSampleRow = []       % sample highlighted in red, if any
    end

    % --------------------------------------------------------------------
    % Menu callbacks
    % --------------------------------------------------------------------
    methods (Access = private)

        function LoadRawDataMenuSelected(app, ~)
            % Import mzXML files, annotate them and save the result.

            importedData = import_raw_data(app.Params);
            if isempty(importedData)
                return      % file dialog cancelled
            end

            [annotatedData, didAnnotate] = annotate_peaks(importedData, app.Params);
            if ~didAnnotate
                uialert(app.UIFigure, ...
                    ['The data were imported but not annotated. Use the ' ...
                     'Annotation menu to annotate them before exporting.'], ...
                    'Annotation skipped', 'Icon', 'warning');
            end

            [fileName, folderPath] = uiputfile('*.mat', 'Save FIA file as');
            if isequal(fileName, 0)
                % Do not throw the import away just because the save dialog
                % was dismissed; keep it open in the app instead.
                app.FiaData = annotatedData;
                app.FiaFilePath = '';
                app.refreshAll();
                return
            end

            todayStamp = char(datetime('today', 'Format', 'yyyyMMdd'));
            app.FiaFilePath = fullfile(folderPath, [todayStamp '_FIA-File_' fileName]);

            app.FiaData = annotatedData;
            app.saveFiaFile();
            app.refreshAll();
        end

        function LoadFiaFileMenuSelected(app, ~)
            % Reopen a previously saved FIA file.

            [loadedData, fullFileName] = load_fia_file();
            if isempty(loadedData)
                return
            end

            app.FiaData = loadedData;
            app.FiaFilePath = fullFileName;

            % Use the settings the file was created with, so the display and
            % any re-annotation match how these data were processed.
            if isfield(loadedData, 'params') && ~isempty(loadedData(1).params)
                app.Params = loadedData(1).params;
            end

            app.refreshAll();
        end

        function AnnotationMenuSelected(app, ~)
            % Re-annotate the open data set against a different database.

            if ~app.hasData()
                uialert(app.UIFigure, 'Load a FIA file first.', 'No data');
                return
            end

            [reannotatedData, didAnnotate] = re_annotate_peaks(app.FiaData, app.Params);
            if ~didAnnotate
                return
            end
            app.FiaData = reannotatedData;

            if isempty(app.FiaFilePath)
                uialert(app.UIFigure, ...
                    ['The data were re-annotated. They have not been saved ' ...
                     'yet, because this data set has no file on disk.'], ...
                    'Re-annotated', 'Icon', 'info');
            else
                app.saveFiaFile();
                uialert(app.UIFigure, ...
                    sprintf('Re-annotated and saved to\n%s', app.FiaFilePath), ...
                    'Re-annotated', 'Icon', 'success');
            end

            app.refreshAll();
        end

        function ExportFiaDataMenuSelected(app, ~)
            % Write the annotated data to an Excel workbook.

            if ~app.hasData()
                uialert(app.UIFigure, 'Load a FIA file first.', 'No data');
                return
            end

            % EXPORT_FIA_DATA works on a copy, so the app keeps every row
            % even though the workbook only has the detected ones.
            export_fia_data(app.FiaData);
        end

        function ExportWorkspaceMenuSelected(app, ~)
            % Put the open data set into the base workspace

            if ~app.hasData()
                uialert(app.UIFigure, 'Load a FIA file first.', 'No data');
                return
            end

            assignin('base', 'fia_data', app.FiaData);

            fprintf(['fia_data is now in your base workspace. It is a copy: ' ...
                'editing it there does not change what the app has.\n']);

            uialert(app.UIFigure, ...
                ['The variable fia_data is now in your base workspace. It is ' ...
                 'a copy, so editing it there does not change what the app ' ...
                 'has.'], 'Sent to workspace', 'Icon', 'success');
        end

    end

    % --------------------------------------------------------------------
    % Table and control callbacks
    % --------------------------------------------------------------------
    methods (Access = private)

        function AnnotationTableCellSelection(app, event)
            if isempty(event.Indices)
                return
            end
            app.SelectedAnnotationRow = event.Indices(1);
            app.updateSpectrumPlot();
        end

        function SampleTableCellSelection(app, event)
            if isempty(event.Indices)
                return
            end
            app.SelectedSampleRow = event.Indices(1);
            app.updateSpectrumPlot();
        end

        function PolaritySwitchValueChanged(app, ~)
            % Both tables belong to the selected polarity. 
            app.SelectedAnnotationRow = [];
            app.SelectedSampleRow = [];
            app.refreshTables();
            cla(app.SpectrumAxes);
        end

        function ZoomSliderValueChanged(app, ~)
            % Redraw 
            app.updateSpectrumPlot();
        end

    end

    % --------------------------------------------------------------------
    % helpers
    % --------------------------------------------------------------------
    methods (Access = private)

        function tf = hasData(app)
            tf = ~isempty(app.FiaData) && isfield(app.FiaData, 'annot') ...
                && ~isempty(app.FiaData(1).annot);
        end

        function mode = currentMode(app)
            % 1 for positive polarity, 2 for negative.
            if strcmp(app.PolaritySwitch.Value, 'Pos')
                mode = 1;
            else
                mode = 2;
            end
        end

        function refreshAll(app)
            app.SelectedAnnotationRow = [];
            app.SelectedSampleRow = [];
            app.refreshTables();
            app.refreshLabels();
            cla(app.SpectrumAxes);
        end

        function refreshTables(app)
            if ~app.hasData()
                app.AnnotationTable.Data = table();
                app.SampleTable.Data = table();
                return
            end

            mode = app.currentMode();
            annot = app.FiaData(mode).annot;

            % Identity and quality columns, then one column per sample.
            displayTable = table( ...
                annot.abbr, annot.MetName, annot.ref_mass, annot.kegg_id, ...
                annot.nIsobars, sum(annot.detected, 2), ...
                'VariableNames', {'abbr', 'MetName', 'mass', 'kegg', ...
                                  'nIsobars', 'nDetected'});

            sampleLabels = matlab.lang.makeValidName( ...
                app.FiaData(mode).sampleLabels(:).');
            sampleLabels = matlab.lang.makeUniqueStrings(sampleLabels);

            app.AnnotationTable.Data = ...
                [displayTable, array2table(annot.Ydata, 'VariableNames', sampleLabels)];

            app.SampleTable.Data = app.FiaData(mode).sampleLabels(:);
        end

        function refreshLabels(app)
            if isempty(app.FiaFilePath)
                app.FiaFilePathLabel.Text = '(not saved)';
            else
                app.FiaFilePathLabel.Text = app.FiaFilePath;
            end

            if app.hasData() && isfield(app.FiaData, 'database')
                app.DatabaseNameLabel.Text = char(string(app.FiaData(1).database));
            else
                app.DatabaseNameLabel.Text = '';
            end
        end

        function updateSpectrumPlot(app)
            % Draw the mass window around the selected ion. 

            if ~app.hasData() || isempty(app.SelectedAnnotationRow)
                return
            end

            mode = app.currentMode();
            modeData = app.FiaData(mode);
            annotationRow = app.SelectedAnnotationRow;

            if annotationRow > height(modeData.annot)
                return
            end

            targetMz = modeData.annot.ref_mass(annotationRow);
            mzGrid = modeData.mz;
            nPoints = numel(mzGrid);

            % Clamp the window to the grid. 
            halfWidth = floor(app.ZoomSlider.Value * 5) + 50;
            [~, centerIndex] = min(abs(mzGrid - targetMz));
            firstIndex = max(1, centerIndex - halfWidth);
            lastIndex  = min(nPoints, centerIndex + halfWidth);
            window = firstIndex:lastIndex;

            windowMz = mzGrid(window);
            windowIntensity = double(modeData.int(:, window));

            cla(app.SpectrumAxes);
            hold(app.SpectrumAxes, 'on');

            plot(app.SpectrumAxes, windowMz, windowIntensity, 'k-');
            xlim(app.SpectrumAxes, [windowMz(1) windowMz(end)]);

            % Expected mass of the selected ion.
            yRange = ylim(app.SpectrumAxes);
            plot(app.SpectrumAxes, [targetMz targetMz], yRange, 'b--', 'LineWidth', 1);

            % Mark the peak used in each sample. Rows that were never
            % detected keep a peakID of 0 and are skipped
            peakGridIndex = modeData.peakID(annotationRow, :);
            for sampleIx = 1:numel(peakGridIndex)
                if peakGridIndex(sampleIx) == 0
                    continue
                end
                plot(app.SpectrumAxes, ...
                    mzGrid(peakGridIndex(sampleIx)), ...
                    double(modeData.int(sampleIx, peakGridIndex(sampleIx))), ...
                    'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 4);
            end

            % Highlight the sample selected on the Samples tab.
            if ~isempty(app.SelectedSampleRow) && app.SelectedSampleRow <= size(windowIntensity, 1)
                plot(app.SpectrumAxes, windowMz, ...
                    windowIntensity(app.SelectedSampleRow, :), 'r-', 'LineWidth', 1.5);
            end

            title(app.SpectrumAxes, sprintf('%s   m/z %.4f', ...
                char(modeData.annot.abbr{annotationRow}), targetMz), ...
                'Interpreter', 'none');

            hold(app.SpectrumAxes, 'off');
        end

        function saveFiaFile(app)
            % The variable is deliberately still called fia_data
            % -v7.3 is required because
            % the intensity matrix routinely exceeds the 2 GB limit of the
            % older MAT formats.
            fia_data = app.FiaData;
            save(app.FiaFilePath, 'fia_data', '-v7.3');

            fprintf('Saved %s\n', app.FiaFilePath);
        end

    end

    % --------------------------------------------------------------------
    % Component initialisation
    % --------------------------------------------------------------------
    methods (Access = private)

        function createComponents(app)

            appFolder = fileparts(mfilename('fullpath'));

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [1 1 1];
            app.UIFigure.Position = [100 100 966 491];
            app.UIFigure.Name = 'FIA Explorer V3';

            % --- menus ---
            app.LoadMenu = uimenu(app.UIFigure);
            app.LoadMenu.Text = 'Load';

            app.LoadFiaFileMenu = uimenu(app.LoadMenu);
            app.LoadFiaFileMenu.Text = 'FIA File';
            app.LoadFiaFileMenu.MenuSelectedFcn = ...
                createCallbackFcn(app, @LoadFiaFileMenuSelected, true);

            app.LoadRawDataMenu = uimenu(app.LoadMenu);
            app.LoadRawDataMenu.Text = 'Raw Data';
            app.LoadRawDataMenu.MenuSelectedFcn = ...
                createCallbackFcn(app, @LoadRawDataMenuSelected, true);

            app.ExportMenu = uimenu(app.UIFigure);
            app.ExportMenu.Text = 'Export';

            app.ExportFiaDataMenu = uimenu(app.ExportMenu);
            app.ExportFiaDataMenu.Text = 'Fia-Data';
            app.ExportFiaDataMenu.MenuSelectedFcn = ...
                createCallbackFcn(app, @ExportFiaDataMenuSelected, true);

            app.ExportWorkspaceMenu = uimenu(app.ExportMenu);
            app.ExportWorkspaceMenu.Text = 'To Workspace (fia_data)';
            app.ExportWorkspaceMenu.MenuSelectedFcn = ...
                createCallbackFcn(app, @ExportWorkspaceMenuSelected, true);

            app.AnnotationMenu = uimenu(app.UIFigure);
            app.AnnotationMenu.Text = 'Annotation';
            app.AnnotationMenu.MenuSelectedFcn = ...
                createCallbackFcn(app, @AnnotationMenuSelected, true);

            % --- spectrum plot ---
            app.SpectrumAxes = uiaxes(app.UIFigure);
            xlabel(app.SpectrumAxes, 'm/z');
            ylabel(app.SpectrumAxes, 'Intensity');
            app.SpectrumAxes.Position = [484 16 464 335];

            % --- tables ---
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [44 40 415 428];

            app.AnnotationTab = uitab(app.TabGroup);
            app.AnnotationTab.Title = 'Annotation';

            app.AnnotationTable = uitable(app.AnnotationTab);
            app.AnnotationTable.RowName = {};
            app.AnnotationTable.Position = [1 1 413 403];
            app.AnnotationTable.CellSelectionCallback = ...
                createCallbackFcn(app, @AnnotationTableCellSelection, true);

            app.SamplesTab = uitab(app.TabGroup);
            app.SamplesTab.Title = 'Samples';

            app.SampleTable = uitable(app.SamplesTab);
            app.SampleTable.RowName = {};
            app.SampleTable.ColumnName = {'Sample'};
            app.SampleTable.Position = [1 1 413 403];
            app.SampleTable.CellSelectionCallback = ...
                createCallbackFcn(app, @SampleTableCellSelection, true);

            % --- header ---
            app.LogoImage = uiimage(app.UIFigure);
            app.LogoImage.Position = [802 382 146 103];
            app.LogoImage.ImageSource = fullfile(appFolder, 'icons-03.png');

            app.TitleLabel = uilabel(app.UIFigure);
            app.TitleLabel.FontSize = 10;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.Position = [834 373 88 22];
            app.TitleLabel.Text = 'FIA Explorer V3';

            % --- controls ---
            app.PolaritySwitchLabel = uilabel(app.UIFigure);
            app.PolaritySwitchLabel.HorizontalAlignment = 'center';
            app.PolaritySwitchLabel.Position = [499 435 35 22];
            app.PolaritySwitchLabel.Text = 'Mode';

            app.PolaritySwitch = uiswitch(app.UIFigure, 'slider');
            app.PolaritySwitch.Items = {'Pos', 'Neg'};
            app.PolaritySwitch.Value = 'Pos';
            app.PolaritySwitch.Position = [576 437 45 20];
            app.PolaritySwitch.ValueChangedFcn = ...
                createCallbackFcn(app, @PolaritySwitchValueChanged, true);

            app.ZoomSliderLabel = uilabel(app.UIFigure);
            app.ZoomSliderLabel.HorizontalAlignment = 'right';
            app.ZoomSliderLabel.Position = [499 394 36 22];
            app.ZoomSliderLabel.Text = 'Zoom';

            app.ZoomSlider = uislider(app.UIFigure);
            app.ZoomSlider.Position = [556 404 150 3];
            app.ZoomSlider.ValueChangedFcn = ...
                createCallbackFcn(app, @ZoomSliderValueChanged, true);

            % --- status bar ---
            app.FiaFileCaptionLabel = uilabel(app.UIFigure);
            app.FiaFileCaptionLabel.FontSize = 9;
            app.FiaFileCaptionLabel.FontWeight = 'bold';
            app.FiaFileCaptionLabel.Position = [8 15 53 27];
            app.FiaFileCaptionLabel.Text = 'FIA-File:';

            app.FiaFilePathLabel = uilabel(app.UIFigure);
            app.FiaFilePathLabel.FontSize = 9;
            app.FiaFilePathLabel.Position = [56 15 625 27];
            app.FiaFilePathLabel.Text = '';

            app.DatabaseCaptionLabel = uilabel(app.UIFigure);
            app.DatabaseCaptionLabel.FontSize = 9;
            app.DatabaseCaptionLabel.FontWeight = 'bold';
            app.DatabaseCaptionLabel.Position = [4 -2 53 27];
            app.DatabaseCaptionLabel.Text = 'Database:';

            app.DatabaseNameLabel = uilabel(app.UIFigure);
            app.DatabaseNameLabel.FontSize = 9;
            app.DatabaseNameLabel.Position = [56 -2 625 27];
            app.DatabaseNameLabel.Text = '';

            app.UIFigure.Visible = 'on';
        end

    end

    % --------------------------------------------------------------------
    % Construction and destruction
    % --------------------------------------------------------------------
    methods (Access = public)

        function app = FiaExplorer_V3()

            % Make the pipeline functions reachable even when only the app
            % folder itself is on the MATLAB path.
            appFolder = fileparts(mfilename('fullpath'));
            addpath(appFolder, ...
                fullfile(appFolder, 'Step 1 Load'), ...
                fullfile(appFolder, 'Step 2 Annotate'), ...
                fullfile(appFolder, 'Step 3 Export Data'));

            app.Params = fia_default_params();

            createComponents(app);
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end

    end

end
