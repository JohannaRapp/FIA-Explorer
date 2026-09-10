function fiaData = import_raw_data(params, rawFiles, measurementDate)
%IMPORT_RAW_DATA  Import a set of FI-MS mzXML files into a fia_data struct.
%
%   FIADATA = IMPORT_RAW_DATA(PARAMS) asks the user to select mzXML files,
%   reduces each one to a single baseline-corrected spectrum (see
%   EXTRACT_SPECTRUM) and returns them as a 1-by-2 struct array:
%
%       fiaData(1)   all samples measured in positive polarity
%       fiaData(2)   all samples measured in negative polarity
%
%   Both entries have the fields
%
%       polarity          "positive" or "negative"
%       mz                1-by-N shared m/z grid
%       int               nSamples-by-N intensity matrix, one row per sample
%       files             source file name of each row
%       samples           sample name of each row (may repeat for replicates)
%       sampleLabels      unique label per row, used as column headings
%       positions         plate position of each row
%       date_FIAfile      date this FIA file was created
%       date_Measurement  date the samples were measured (NaT if not given)
%       VersionMSConvert  MSConvert version that produced the mzXML files
%       VersionFIAExpl    version of this software
%       params            the PARAMS struct used, kept for provenance
%       formatVersion     layout version of this struct
%
%   FIADATA is empty if the user cancels the file dialog.
%
%   File names must match PARAMS.fileNamePattern, that is
%   <sample>_<position>_<polarity>.mzXML with polarity "pos" or "neg", for
%   example "aroC_P6-A1_pos.mzXML". Every sample should be measured in both
%   polarities.
%
%   FIADATA = IMPORT_RAW_DATA(PARAMS, RAWFILES, MEASUREMENTDATE) skips both
%   dialogs. RAWFILES is a folder with .mzXML files, or a cell array of
%   full paths to them; MEASUREMENTDATE is optional and defaults to NaT.
%
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    params (1,1) struct = fia_default_params()
    rawFiles = []
    measurementDate (1,1) datetime = NaT
end

fiaData = [];

% ------------------------------------------------------------------------
% 1. Select the raw files
% ------------------------------------------------------------------------

if isempty(rawFiles)
    [selectedFiles, folderPath] = uigetfile('*.mzXML', ...
        'Select .mzXML files', 'MultiSelect', 'on');

    if isequal(selectedFiles, 0)
        return
    end
    if ischar(selectedFiles)
        selectedFiles = {selectedFiles};
    end

    measurementDate = ask_measurement_date();
else
    [selectedFiles, folderPath] = resolve_raw_files(rawFiles);
end

fileNames = sort(selectedFiles(:)).';   % deterministic, reproducible order

% ------------------------------------------------------------------------
% 2. Read sample name, plate position and polarity out of the file names
% ------------------------------------------------------------------------

nFiles = numel(fileNames);
sampleName    = cell(nFiles, 1);
platePosition = cell(nFiles, 1);
polarityTag   = cell(nFiles, 1);

for k = 1:nFiles
    nameParts = regexp(fileNames{k}, params.fileNamePattern, ...
        'names', 'once', 'ignorecase');

    if isempty(nameParts)
        error('import_raw_data:badFileName', ...
            ['File name "%s" cannot be interpreted.\nExpected ' ...
             '<sample>_<position>_<polarity>.mzXML with polarity "pos" or ' ...
             '"neg", for example "aroC_P6-A1_pos.mzXML".'], fileNames{k});
    end

    sampleName{k}    = nameParts.sample;
    platePosition{k} = nameParts.position;
    polarityTag{k}   = lower(nameParts.polarity);
end

% ------------------------------------------------------------------------
% 3. Read the spectra
% ------------------------------------------------------------------------

% Preallocate the intensity matrix. 

if params.storeIntensitiesAsSingle
    intensityClass = 'single';
else
    intensityClass = 'double';
end
allIntensities = zeros(nFiles, params.nResamplePoints, intensityClass);
mzGrid = [];
msconvertVersion = "unknown";

for k = 1:nFiles
    fprintf('file %d of %d - %s\n', k, nFiles, fileNames{k});

    [fileMzGrid, fileIntensity, fileMsconvertVersion] = ...
        extract_spectrum(fullfile(folderPath, fileNames{k}), params);

    % Every file is resampled onto the same grid
    if k == 1
        mzGrid = fileMzGrid;
        msconvertVersion = fileMsconvertVersion;
    elseif ~isequal(size(fileMzGrid), size(mzGrid))
        error('import_raw_data:gridMismatch', ...
            'File "%s" produced a different m/z grid than the first file.', ...
            fileNames{k});
    end

    allIntensities(k, :) = fileIntensity;
end

% ------------------------------------------------------------------------
% 4. Split into the two polarities
% ------------------------------------------------------------------------

fiaData = struct( ...
    'polarity',         {"positive", "negative"}, ...
    'mz',               {mzGrid, mzGrid}, ...
    'int',              {[], []}, ...
    'files',            {{}, {}}, ...
    'samples',          {{}, {}}, ...
    'sampleLabels',     {{}, {}}, ...
    'positions',        {{}, {}}, ...
    'date_FIAfile',     {datetime('today'), datetime('today')}, ...
    'date_Measurement', {measurementDate, measurementDate}, ...
    'VersionMSConvert', {msconvertVersion, msconvertVersion}, ...
    'VersionFIAExpl',   {params.softwareVersion, params.softwareVersion}, ...
    'params',           {params, params}, ...
    'formatVersion',    {params.formatVersion, params.formatVersion});

polarityOfMode = {'pos', 'neg'};

for mode = 1:2
    rowsInMode = find(strcmp(polarityTag, polarityOfMode{mode}));

    if isempty(rowsInMode)
        warning('import_raw_data:missingPolarity', ...
            'No files were selected for %s polarity.', fiaData(mode).polarity);
    end

    % Sort by sample then position so that both polarities end up in the
    % same row order, and row i of one always refers to the same physical
    % sample as row i of the other.
    [~, sortOrder] = sortrows([sampleName(rowsInMode), platePosition(rowsInMode)]);
    rowsInMode = rowsInMode(sortOrder);

    fiaData(mode).int       = allIntensities(rowsInMode, :);
    fiaData(mode).files     = fileNames(rowsInMode);
    fiaData(mode).samples   = sampleName(rowsInMode);
    fiaData(mode).positions = platePosition(rowsInMode);

    % Replicates of one strain share a sample name, but Excel column
    % headings and MATLAB table variables have to be unique. Fall back to
    % "<sample>_<position>" for the duplicates. 

    fiaData(mode).sampleLabels = make_unique_labels( ...
        fiaData(mode).samples, fiaData(mode).positions);
end

% ERROR HANDLING: A sample measured in only one polarity 
% is almost always a mistake

if ~isequal(fiaData(1).samples, fiaData(2).samples)
    warning('import_raw_data:polarityMismatch', ...
        ['The positive and negative sample lists differ. Check that every ' ...
         'sample was measured in both polarities and that the file names ' ...
         'follow the expected pattern.']);
end

fprintf('Imported %d samples in positive and %d in negative polarity.\n', ...
    numel(fiaData(1).samples), numel(fiaData(2).samples));

end


% ------------------------------------------------------------------------

function [fileNames, folderPath] = resolve_raw_files(rawFiles)
%RESOLVE_RAW_FILES  Accept a folder or a list of paths, return names + folder.
%
%   The reading loop builds each path with FULLFILE(folderPath, name), so the
%   files have to share one folder. That is how a plate is always laid out,
%   and requiring it keeps the non-interactive form equivalent to what the
%   file dialog produces.

if ischar(rawFiles) || isstring(rawFiles)
    rawFiles = char(rawFiles);

    if isfolder(rawFiles)
        found = dir(fullfile(rawFiles, '*.mzXML'));
        if isempty(found)
            error('import_raw_data:noFilesInFolder', ...
                'No .mzXML files found in %s.', rawFiles);
        end
        folderPath = rawFiles;
        fileNames = {found.name};
        return
    end

    rawFiles = {rawFiles};
end

if ~iscell(rawFiles)
    error('import_raw_data:badRawFiles', ...
        'rawFiles must be a folder, a file path, or a cell array of file paths.');
end

folders = cell(size(rawFiles));
fileNames = cell(size(rawFiles));
for k = 1:numel(rawFiles)
    if ~isfile(rawFiles{k})
        error('import_raw_data:fileNotFound', 'File not found: %s', rawFiles{k});
    end
    [folders{k}, name, ext] = fileparts(rawFiles{k});
    fileNames{k} = [name ext];
end

uniqueFolders = unique(folders);
if numel(uniqueFolders) > 1
    error('import_raw_data:multipleFolders', ...
        'All raw files must live in one folder; %d different folders were given.', ...
        numel(uniqueFolders));
end
folderPath = uniqueFolders{1};

end
