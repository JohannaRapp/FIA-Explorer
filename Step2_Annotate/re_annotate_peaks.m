function [fiaData, didAnnotate] = re_annotate_peaks(fiaData, params, databaseFile)
%RE_ANNOTATE_PEAKS  Annotate an existing data set against another database.
%
%   [FIADATA, DIDANNOTATE] = RE_ANNOTATE_PEAKS(FIADATA, PARAMS) discards the
%   current annotation and builds a new one from a database chosen by the
%   user. Peak picking is repeated from the stored spectra, so no raw mzXML
%   files are needed. DIDANNOTATE is false if the user cancels.
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    fiaData (1,:) struct
    params (1,1) struct = fia_default_params()
    databaseFile (1,:) char = ''
end

[fiaData, didAnnotate] = annotate_peaks(fiaData, params, databaseFile);

end
