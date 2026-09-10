function [mzGrid, summedIntensity, msconvertVersion, ticPerScan] = extract_spectrum(filePath, params)
%EXTRACT_SPECTRUM  Read one mzXML file and reduce it to a single spectrum.
%
%   [MZGRID, SUMMEDINTENSITY] = EXTRACT_SPECTRUM(FILEPATH, PARAMS) reads the
%   mzXML file FILEPATH and makes it into one spectrum (sums up specified spectra).
%
%     1. the scans in PARAMS.scanRange are selected (def is [4 36]),
%     2. each scan is resampled onto the same m/z grid so that scans can be compard
%          directly 
%     3. the resampled scans are summed, and
%     4. the summed trace is baseline corrected with MSBACKADJ (matlab functio).
%
%   MZGRID is a 1-by-N row vector of m/z values and SUMMEDINTENSITY is the
%   matching 1-by-N row vector of baseline-corrected intensities. The grid is
%   identical for every file processed with the same PARAMS
%
%   [..., MSCONVERTVERSION, TICPERSCAN] = EXTRACT_SPECTRUM(...) also returns
%   the version of MSConvert that produced the file
%   and the total ion current of every scan in the file.
%   TICPERSCAN is useful for checking that PARAMS.scanRange really covers the
%   flat part of the injection profile for this instrument and method:
%
%       [~, ~, ~, tic] = extract_spectrum(file, fia_default_params());
%       plot(tic); xlabel('scan'); ylabel('total ion current')
%
%   Requires the Bioinformatics Toolbox (MSRESAMPLE, MSBACKADJ). 
%
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    filePath (1,:) char
    params (1,1) struct
end

firstScan = params.scanRange(1);
lastScan  = params.scanRange(2);
scanIndices = firstScan:lastScan;

% Decoding the peak data is by far the most expensive part of reading a
% file, so ask only for the scans that will actually be summed. Attributes,
% and therefore ticPerScan, are still returned for the whole run.
try
    rawFile = read_mzxml(filePath, scanIndices);
catch err
    % Failed
    if strcmp(err.identifier, 'read_mzxml:badScanIndices')
        error('extract_spectrum:tooFewScans', ...
            ['"%s" does not contain scans %d to %d, which params.scanRange ' ...
             'asks for. Shorten params.scanRange or check the acquisition.'], ...
            filePath, firstScan, lastScan);
    end
    rethrow(err);
end

ticPerScan = [rawFile.scan(:).totIonCurrent];

% Resample every selected scan onto the shared grid before summing. 
resampledScans = zeros(numel(scanIndices), params.nResamplePoints);

for k = 1:numel(scanIndices)
    scan = rawFile.scan(scanIndices(k));

    % mzXML stores each scan as one interleaved vector: m/z, intensity,
    % m/z, intensity, ... Odd elements are masses, even ones intensities.
    scanMz        = scan.peaks.mz(1:2:end-1);
    scanIntensity = scan.peaks.mz(2:2:end);

    [mzGrid, resampledScans(k, :)] = msresample( ...
        scanMz, scanIntensity, params.nResamplePoints, ...
        'Range', params.mzRange, 'Uniform', true);
end

% rounding int to make it compact.
summedIntensity = round(sum(resampledScans, 1));

% MSBACKADJ baseline correction.
mzGrid = mzGrid(:).';
summedIntensity = msbackadj(mzGrid.', summedIntensity.').';

msconvertVersion = string(rawFile.mzXML.msRun.dataProcessing.software.version);

end
