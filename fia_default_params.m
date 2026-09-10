function params = fia_default_params()
%FIA_DEFAULT_PARAMS  Central configuration for the FIA Explorer pipeline.
%
%   PARAMS = FIA_DEFAULT_PARAMS() returns a struct holding every tuning
%   constant used by the import, annotation and export steps. 
%
%   To deviate from the defaults for a single analysis:
%
%       params = fia_default_params();
%       params.minPeakHeight = 2000;            % more sensitive peak picking
%       params.massTolerancePpm = 5;            % add a ppm-scaled tolerance
%       fiaData = import_raw_data(params);
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

% ------------------------------------------------------------------------
% Raw data import (see EXTRACT_SPECTRUM)
% ------------------------------------------------------------------------

% Range of scans summed into one spectrum. Flow injection produces a short
% intensity plateau; the leading scans (solvent front) and trailing scans
% (wash-out) are discarded.
params.scanRange = [4 36];

% m/z window kept after resampling, in Da. Chosen just inside the acquired
% range (50-1700 Da) edges of the acquisition window are excluded.
params.mzRange = [51 1699];

% Number of points on the common m/z grid that every scan of every file is
% resampled onto. All samples must share one grid so that intensities can be
% compared column-wise. 2e6 points over 51-1699 Da gives a spacing of
% roughly 0.8 mDa, i.e. about four points across the 3 mDa mass tolerance.
params.nResamplePoints = 2e6;

% Store the summed intensity matrix as single precision. Intensities are
% rounded ion counts, so single (7 significant digits) is ample and halves
% the memory needed for the largest field in the data set: a 96-sample run
% needs 0.8 GB as single instead of 1.5 GB as double.
params.storeIntensitiesAsSingle = true;

% ------------------------------------------------------------------------
% Peak picking (see ANNOTATE_PEAKS)
% ------------------------------------------------------------------------

% Minimum absolute intensity for FINDPEAKS to pick a peak.
params.minPeakHeight = 5000;

% Minimum prominence (height above the surrounding baseline) for FINDPEAKS.
% Rejects shoulders
params.minPeakProminence = 5000;

% ------------------------------------------------------------------------
% Annotation (see MATCH_MASSES_TO_PEAKS)
% ------------------------------------------------------------------------

% Constant part of the mass tolerance, in Da.
params.massToleranceDa = 0.003;

% Mass-proportional part of the tolerance, in ppm. The tolerance actually
% applied to a reference mass is
%
%       max(massToleranceDa, massTolerancePpm * refMass / 1e6)
%
% A flat 3 mDa window is 59 ppm at m/z 51 but only 1.8 ppm at m/z 1699,
% which is far tighter than a TOF instrument holds across that range. Set
% massTolerancePpm to e.g. 5 to widen the window for heavy ions. 
params.massTolerancePpm = 0;

% Adducts used to convert neutral database masses into expected ion masses.
% Run ADDUCT_DEFINITIONS to list every supported name.
params.adductsPositive = {'[M+H]+'};
params.adductsNegative = {'[M-H]-'};

% Fill gaps in the intensity matrix by reading the raw baseline-corrected
% signal at the expected m/z, for metabolites that produced a real peak in
% at least one other sample (see IMPUTE_MISSING_INTENSITIES).
params.imputeMissingIntensities = true;

% ------------------------------------------------------------------------
% File naming (see IMPORT_RAW_DATA)
% ------------------------------------------------------------------------

% Raw file names must match <sample>_<position>_<polarity>.mzXML, where
% polarity is "pos" or "neg". Everything before the second-to-last
% underscore is taken as the sample name, so "aroC_P6-A1_pos.mzXML" belongs
% to sample "aroC" measured at plate position "P6-A1".
params.fileNamePattern = '^(?<sample>.+)_(?<position>[^_]+)_(?<polarity>pos|neg)\.mzXML$';

% ------------------------------------------------------------------------
% Provenance
% ------------------------------------------------------------------------

% Written into every FIA file and every exported workbook. 
params.softwareVersion = "FIA_Explorer_V3.0";

% Version of the fia_data struct layout itself.
params.formatVersion = 3;

end
