function outputFile = export_fia_data(fiaData, exportKind, outputFile)
%EXPORT_FIA_DATA  Write the annotated data to an Excel workbook.
%
%   OUTPUTFILE = EXPORT_FIA_DATA(FIADATA) asks what to export and where, and
%   writes one workbook. OUTPUTFILE is '' if the user cancels.
%
%   Two kinds of export are offered:
%
%     Annotated ions raw   intensities as annotated
%     Annotated ions FC    fold changes, each metabolite divided by its own
%                          mean across all samples
%
%   EXPORT_FIA_DATA(FIADATA, EXPORTKIND, OUTPUTFILE) skips both dialogs.
%   EXPORTKIND is "raw" or "foldchange" and OUTPUTFILE is the full path of
%   the workbook to write, used exactly as given. This form makes the export
%   usable from a batch script and from the test suite.
%
%   The workbook has these sheets
%
%     pos, neg                    identity columns then one column per sample
%     pos_detected, neg_detected  the same layout, true where the value came
%                                 from a real picked peak and false where it
%                                 was imputed from the raw spectrum
%     Database                    database, software versions, dates and the
%                                 full parameter set used
%
%
%   NOTE that Metabolites not detected in any sample are omitted
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. AUg 2026

arguments
    fiaData (1,:) struct
    exportKind (1,:) char {mustBeMember(exportKind, {'', 'raw', 'foldchange'})} = ''
    outputFile (1,:) char = ''
end

if ~isfield(fiaData, 'annot') || isempty(fiaData(1).annot)
    error('export_fia_data:notAnnotated', ...
        'This data set has not been annotated yet. Run the annotation first.');
end

% ------------------------------------------------------------------------
% 1. Decide what to export and where to put it
% ------------------------------------------------------------------------

if isempty(exportKind)
    exportKinds = {'Annotated ions raw', 'Annotated ions FC'};
    [selection, wasChosen] = listdlg('PromptString', {'Select what you want to export'}, ...
        'SelectionMode', 'single', 'ListString', exportKinds, 'ListSize', [220 80]);

    if ~wasChosen
        outputFile = '';
        return
    end
    exportKinds = {'raw', 'foldchange'};
    exportKind = exportKinds{selection};
end

exportFoldChanges = strcmp(exportKind, 'foldchange');

if isempty(outputFile)
    [chosenName, chosenFolder] = uiputfile('*.xlsx', 'Export as');
    if isequal(chosenName, 0)
        outputFile = '';
        return
    end

    if exportFoldChanges
        filePrefix = '_FIA_Fc_';
    else
        filePrefix = '_FIA-Data_';
    end

    todayStamp = char(datetime('today', 'Format', 'yyyyMMdd'));
    outputFile = fullfile(chosenFolder, [todayStamp filePrefix chosenName]);
end

% Writing to an existing workbook keeps whatever sheets are already in it,
% which silently mixes results from two different runs.
if isfile(outputFile)
    delete(outputFile);
end

% ------------------------------------------------------------------------
% 2. One pair of sheets per polarity
% ------------------------------------------------------------------------

sheetOfMode = {'pos', 'neg'};

for mode = 1:2
    annot = fiaData(mode).annot;
    if isempty(annot)
        continue
    end

    % Leave out metabolites that were never detected. 
    wasEverDetected = any(annot.detected, 2);
    annot = annot(wasEverDetected, :);

    if isempty(annot)
        warning('export_fia_data:nothingDetected', ...
            'No metabolite was detected in %s polarity; its sheet is empty.', ...
            fiaData(mode).polarity);
    end

    sampleLabels = sample_column_names(fiaData(mode));

    intensity = annot.Ydata;
    if exportFoldChanges
        intensity = to_fold_change(intensity);
    end

    identity = table( ...
        annot.abbr, annot.MetName, annot.ref_mass, annot.kegg_id, ...
        annot.adduct, annot.nIsobars, annot.deltaMz * 1000, sum(annot.detected, 2), ...
        'VariableNames', {'abbr', 'MetName', 'mass', 'kegg', ...
                          'adduct', 'nIsobars', 'deltaMz_mDa', 'nDetected'});

    writetable([identity, array2table(intensity, 'VariableNames', sampleLabels)], ...
        outputFile, 'Sheet', sheetOfMode{mode});

    writetable([identity, array2table(double(annot.detected), 'VariableNames', sampleLabels)], ...
        outputFile, 'Sheet', [sheetOfMode{mode} '_detected']);
end

% ------------------------------------------------------------------------
% 3. Provenance
% ------------------------------------------------------------------------

writetable(provenance_table(fiaData), outputFile, 'Sheet', 'Database');

fprintf('Exported to %s\n', outputFile);

end

% ------------------------------------------------------------------------

function foldChange = to_fold_change(intensity)
%TO_FOLD_CHANGE  Divide each metabolite by its own mean across samples.

meanPerMetabolite = mean(intensity, 2);

% A row that averages to zero cannot be expressed as a fold change. This
% cannot happen for rows kept by the export, but guarding here turns a
% future change of the filtering rule into visible NaNs rather than Inf.
meanPerMetabolite(meanPerMetabolite == 0) = NaN;

foldChange = intensity ./ meanPerMetabolite;

end

% ------------------------------------------------------------------------

function labels = sample_column_names(modeData)
%SAMPLE_COLUMN_NAMES  Unique, Excel-safe column heading per sample.

if isfield(modeData, 'sampleLabels') && ~isempty(modeData.sampleLabels)
    labels = modeData.sampleLabels(:).';
else
    labels = modeData.samples(:).';  
end

labels = matlab.lang.makeValidName(labels);
labels = matlab.lang.makeUniqueStrings(labels);

end

% ------------------------------------------------------------------------

function provenance = provenance_table(fiaData)
%PROVENANCE_TABLE  Everything needed to reproduce this export.

params = fiaData(1).params;

entries = {
    'Database',            as_text(fiaData(1).database)
    'Software',            as_text(fiaData(1).VersionFIAExpl)
    'MSConvert',           as_text(fiaData(1).VersionMSConvert)
    'FIA file created',    as_text(fiaData(1).date_FIAfile)
    'Measurement date',    as_text(fiaData(1).date_Measurement)
    'Exported',            as_text(datetime('now'))
    'Samples positive',    num2str(numel(fiaData(1).samples))
    'Samples negative',    num2str(numel(fiaData(2).samples))
    'Adducts positive',    strjoin(params.adductsPositive, ', ')
    'Adducts negative',    strjoin(params.adductsNegative, ', ')
    'Scan range',          mat2str(params.scanRange)
    'm/z range',           mat2str(params.mzRange)
    'Resample points',     num2str(params.nResamplePoints)
    'Min peak height',     num2str(params.minPeakHeight)
    'Min peak prominence', num2str(params.minPeakProminence)
    'Mass tolerance (Da)', num2str(params.massToleranceDa)
    'Mass tolerance (ppm)', num2str(params.massTolerancePpm)
    'Imputation',          mat2str(params.imputeMissingIntensities)
    };

provenance = cell2table(entries, 'VariableNames', {'Setting', 'Value'});

end

% ------------------------------------------------------------------------

function text = as_text(value)
%AS_TEXT  Render a provenance value as a character vector.

if iscell(value)
    value = string(value);
end

text = string(value);

if isempty(text) || all(ismissing(text))
    text = "";
end

text = char(strjoin(text(~ismissing(text)), ', '));

end
