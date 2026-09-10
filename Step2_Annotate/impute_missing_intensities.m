function fiaData = impute_missing_intensities(fiaData, params)
%IMPUTE_MISSING_INTENSITIES  Fill annotation gaps from the raw spectrum.
%
%   FIADATA = IMPUTE_MISSING_INTENSITIES(FIADATA, PARAMS) looks for
%   metabolites that produced a real peak in at least one sample but not in
%   all of them, and fills the missing entries with the baseline-corrected
%   raw intensity at the expected m/z.
%
%   Imputed values are NOT marked in annot.detected, which stays false for
%   them. That flag is the only record of how each number was obtained, and
%   EXPORT_FIA_DATA writes it out alongside the intensities.
%
%   NOTE that a baseline-corrected raw reading can be slightly negative
%   where there is no signal at all. (must be filtered in later analysis).
%
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    fiaData (1,:) struct
    params (1,1) struct = fia_default_params() %#ok<INUSA>
end

for mode = 1:numel(fiaData)
    if ~isfield(fiaData, 'annot') || isempty(fiaData(mode).annot)
        continue
    end

    annot = fiaData(mode).annot;
    nSamples = size(annot.Ydata, 2);
    if nSamples == 0
        continue
    end

    fprintf('Please wait... imputing mode %d ... %d metabolites\n', ...
        mode, height(annot));

    % Only rows detected somewhere but not everywhere need filling.
    nDetections = sum(annot.detected, 2);
    rowsToFill = find(nDetections > 0 & nDetections < nSamples);

    if isempty(rowsToFill)
        continue
    end

    gridIndex = nearest_grid_index(fiaData(mode).mz, annot.ref_mass(rowsToFill));

    % Pull the raw intensity at each expected mass for every sample at once:
    % a nSamples-by-nRowsToFill slice, transposed to match the annotation
    % layout.
    rawAtExpectedMass = double(fiaData(mode).int(:, gridIndex)).';

    isMissing = ~annot.detected(rowsToFill, :);

    filledIntensity = annot.Ydata(rowsToFill, :);
    filledIntensity(isMissing) = rawAtExpectedMass(isMissing);
    annot.Ydata(rowsToFill, :) = filledIntensity;

    % Point peakID at the grid position that was read, so the app can mark
    % it in the spectrum plot just like a genuinely picked peak.
    filledPeakId = fiaData(mode).peakID(rowsToFill, :);
    gridIndexPerSample = repmat(gridIndex, 1, nSamples);
    filledPeakId(isMissing) = gridIndexPerSample(isMissing);
    fiaData(mode).peakID(rowsToFill, :) = filledPeakId;

    fiaData(mode).annot = annot;
end

end

% ------------------------------------------------------------------------

function gridIndex = nearest_grid_index(mzGrid, targetMz)
%NEAREST_GRID_INDEX  Index of the grid point closest to each target mass.

mzGrid = mzGrid(:);
nPoints = numel(mzGrid);
targetMz = targetMz(:);

gridStep = (mzGrid(end) - mzGrid(1)) / (nPoints - 1);

% MSRESAMPLE was called with 'Uniform', true, so the spacing is constant 
% Check this:
isUniform = max(abs(diff(mzGrid) - gridStep)) < 1e-9 * gridStep;

if isUniform
    gridIndex = round((targetMz - mzGrid(1)) / gridStep) + 1;
    gridIndex = min(max(gridIndex, 1), nPoints);
else
    gridIndex = round(interp1(mzGrid, (1:nPoints).', targetMz, 'nearest', 'extrap'));
end

end
