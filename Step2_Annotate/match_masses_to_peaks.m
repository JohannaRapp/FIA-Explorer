function [peakIndex, deltaMz] = match_masses_to_peaks(peakMz, referenceMz, params)
%MATCH_MASSES_TO_PEAKS  Assign each reference mass to its nearest peak.
%
%   [PEAKINDEX, DELTAMZ] = MATCH_MASSES_TO_PEAKS(PEAKMZ, REFERENCEMZ, PARAMS)
%   finds, for every expected ion mass in REFERENCEMZ, the closest detected
%   peak in PEAKMZ. A match counts only if the two lie within
%   MASS_TOLERANCE of each other.
%
%   PEAKINDEX(k) is the index into PEAKMZ of the peak assigned to
%   REFERENCEMZ(k), or 0 when no peak is close enough. DELTAMZ(k) is the
%   signed mass error referenceMz - peakMz of that match
%
%   PEAKMZ must be sorted ascending, which is how FINDPEAKS returns peaks
%   picked off an ascending m/z grid.
%
%   NOTE that two reference masses closer together than the tolerance can be
%   assigned to the same peak. ANNOTATE_PEAKS
%   records how many database entries share each mass in the nIsobars
%   column so the ambiguity is visible in the results. (THIS IS NOT
%   Isobars that are already merged in the database).
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    peakMz (:,1) double
    referenceMz (:,1) double
    params (1,1) struct
end

nPeaks = numel(peakMz);
nReferences = numel(referenceMz);

peakIndex = zeros(nReferences, 1);
deltaMz = nan(nReferences, 1);

if nPeaks == 0 || nReferences == 0
    return
end

tolerance = mass_tolerance(referenceMz, params);

if nPeaks == 1
    % INTERP1 needs at least two sample points, so handle the degenerate
    % case directly.
    nearestPeak = ones(nReferences, 1);
else
    nearestPeak = round(interp1(peakMz, (1:nPeaks).', referenceMz, ...
        'nearest', 'extrap'));
end

candidateError = referenceMz - peakMz(nearestPeak);
isMatched = abs(candidateError) <= tolerance;

peakIndex(isMatched) = nearestPeak(isMatched);
deltaMz(isMatched) = candidateError(isMatched);

end
