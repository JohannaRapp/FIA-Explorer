function [fiaData, didAnnotate] = annotate_peaks(fiaData, params, databaseFile)
%ANNOTATE_PEAKS  Detect peaks and match them against a metabolite database.
%
%   FIADATA = ANNOTATE_PEAKS(FIADATA, PARAMS) picks peaks in every sample of
%   both polarities, matches them against a metabolite database 
%   and writes the result back into FIADATA. It then fills the
%   remaining gaps with IMPUTE_MISSING_INTENSITIES.
%
%   [FIADATA, DIDANNOTATE] = ANNOTATE_PEAKS(...) reports whether an
%   annotation actually ran. DIDANNOTATE is false when the user cancels the
%   database dialog, in which case FIADATA is returned unchanged.
%
%   Any annotation already present is replaced, so this one function serves
%   both the first annotation of a freshly imported data set and a later
%   re-annotation against a different database (see RE_ANNOTATE_PEAKS).
%
%   Each polarity gets the fields
%
%       annot     one row per expected ion, with columns
%                   abbr      abbreviation with adduct appended
%                   MetName   metabolite name with adduct appended
%                   ref_mass  expected m/z
%                   kegg_id   KEGG identifier
%                   adduct    adduct on its own
%                   nIsobars  how many database entries share this m/z
%                             within the mass tolerance; 1 means unique
%                   deltaMz   median mass error over the detected samples
%                   Ydata     intensity per sample
%                   detected  true where Ydata came from a real picked peak,
%                             false where it was imputed or is zero
%                   dbRow     row of the source database
%       peakID    index into the m/z grid of the peak used per sample
%       database  name of the database file used
%
%   Requires the Signal Processing Toolbox (FINDPEAKS).
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    fiaData (1,:) struct
    params (1,1) struct = fia_default_params()
    databaseFile (1,:) char = ''
end

didAnnotate = false;

% ------------------------------------------------------------------------
% 1. Choose and load the metabolite database
% ------------------------------------------------------------------------

% Locate Databases
databaseFolder = fullfile(fileparts(mfilename('fullpath')), 'Databases');

if isempty(databaseFile)
    databaseFile = ask_for_database(databaseFolder);
    if isempty(databaseFile)
        return      % dialog cancelled, leave fiaData untouched
    end
end

% Accept either the name of a bundled database or a full path to one
% elsewhere, so a project-specific database does not have to be copied
% into the installation folder.
if isfile(databaseFile)
    databasePath = databaseFile;
else
    databasePath = fullfile(databaseFolder, databaseFile);
end

if ~isfile(databasePath)
    error('annotate_peaks:databaseNotFound', ...
        'Database "%s" was not found in %s.', databaseFile, databaseFolder);
end

loadedDb = load(databasePath, 'db_annot');
if ~isfield(loadedDb, 'db_annot')
    error('annotate_peaks:badDatabase', ...
        '"%s" does not contain a variable called db_annot.', databaseFile);
end
metaboliteDb = loadedDb.db_annot;

adductsOfMode = {params.adductsPositive, params.adductsNegative};

% ------------------------------------------------------------------------
% 2. Annotate each polarity
% ------------------------------------------------------------------------

for mode = 1:2
    nSamples = numel(fiaData(mode).samples);
    if nSamples == 0
        continue
    end

    mzGrid = fiaData(mode).mz(:);

    % Build the reference list (from database and the adducts)
    referenceList = get_adduct_masses(metaboliteDb, adductsOfMode{mode}, mode);
    referenceMz = referenceList.ref_mass;
    nReferences = height(referenceList);

    intensityPerSample = zeros(nReferences, nSamples);
    gridIndexPerSample = zeros(nReferences, nSamples);
    isDetected         = false(nReferences, nSamples);
    massErrorPerSample = nan(nReferences, nSamples);

    for sampleIx = 1:nSamples
        fprintf('Please wait... annotating mode %d ... sample %d of %d\n', ...
            mode, sampleIx, nSamples);

        spectrum = double(fiaData(mode).int(sampleIx, :));

        [peakHeight, peakGridIndex] = findpeaks(spectrum, ...
            'MinPeakHeight', params.minPeakHeight, ...
            'MinPeakProminence', params.minPeakProminence);

        [matchedPeak, massError] = match_masses_to_peaks( ...
            mzGrid(peakGridIndex), referenceMz, params);

        wasMatched = matchedPeak ~= 0;

        intensityPerSample(wasMatched, sampleIx) = peakHeight(matchedPeak(wasMatched));
        gridIndexPerSample(wasMatched, sampleIx) = peakGridIndex(matchedPeak(wasMatched));
        massErrorPerSample(wasMatched, sampleIx) = massError(wasMatched);
        isDetected(wasMatched, sampleIx) = true;
    end

    annot = referenceList;
    annot.nIsobars = count_isobaric_entries(referenceMz, params);
    annot.deltaMz  = median(massErrorPerSample, 2, 'omitnan');
    annot.Ydata    = intensityPerSample;
    annot.detected = isDetected;

    % Put the identifying columns first
    annot = annot(:, {'abbr', 'MetName', 'ref_mass', 'kegg_id', 'adduct', ...
                      'nIsobars', 'deltaMz', 'Ydata', 'detected', 'dbRow'});

    fiaData(mode).annot    = annot;
    fiaData(mode).peakID   = gridIndexPerSample;
    fiaData(mode).database = {databaseFile};
end

% ------------------------------------------------------------------------
% 3. Fill the gaps
% ------------------------------------------------------------------------

if params.imputeMissingIntensities
    fiaData = impute_missing_intensities(fiaData, params);
end

didAnnotate = true;

end

% ------------------------------------------------------------------------

function databaseFile = ask_for_database(databaseFolder)
%ASK_FOR_DATABASE  Let the user pick one of the bundled .mat databases.
%
%   The list is read from the folder instead of being hard-coded, so a new
%   database can be dropped in without editing any code.

available = dir(fullfile(databaseFolder, 'db_*.mat'));
databaseFile = '';

if isempty(available)
    error('annotate_peaks:noDatabases', ...
        'No db_*.mat files were found in %s.', databaseFolder);
end

databaseNames = {available.name};
[selection, wasChosen] = listdlg('ListString', databaseNames, ...
    'SelectionMode', 'single', 'Name', 'Annotation database', ...
    'PromptString', 'Select a database for annotation:', ...
    'ListSize', [260 220]);

if wasChosen
    databaseFile = databaseNames{selection};
end

end

% ------------------------------------------------------------------------

function nIsobars = count_isobaric_entries(referenceMz, params)
%COUNT_ISOBARIC_ENTRIES  How many reference entries share each mass.

nReferences = numel(referenceMz);
nIsobars = ones(nReferences, 1);

if nReferences < 2
    return
end

[sortedMz, sortOrder] = sort(referenceMz(:));
tolerance = mass_tolerance(sortedMz, params);

countSorted = zeros(nReferences, 1);
firstInWindow = 1;
lastInWindow = 1;

for k = 1:nReferences
    while sortedMz(firstInWindow) < sortedMz(k) - tolerance(k)
        firstInWindow = firstInWindow + 1;
    end
    while lastInWindow < nReferences && sortedMz(lastInWindow + 1) <= sortedMz(k) + tolerance(k)
        lastInWindow = lastInWindow + 1;
    end
    countSorted(k) = lastInWindow - firstInWindow + 1;
end

nIsobars(sortOrder) = countSorted;

end
