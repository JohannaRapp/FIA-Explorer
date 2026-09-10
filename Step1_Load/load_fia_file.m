function [fiaData, fullFileName] = load_fia_file(fullFileName)
%LOAD_FIA_FILE  Load a saved FIA file and bring it up to the current layout.
%
%   [FIADATA, FULLFILENAME] = LOAD_FIA_FILE() asks the user to pick a .mat
%   file written by IMPORT_RAW_DATA and returns the
%   fia_data struct it contains. FIADATA is empty if the dialog is cancelled.
%
%   [...] = LOAD_FIA_FILE(FULLFILENAME) loads that file without prompting.
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

arguments
    fullFileName (1,:) char = ''
end

fiaData = [];

if isempty(fullFileName)
    [fileName, folderPath] = uigetfile('*.mat', 'Select FIA file');
    if isequal(fileName, 0)
        fullFileName = '';
        return
    end
    fullFileName = fullfile(folderPath, fileName);
end

loaded = load(fullFileName, 'fia_data');

if ~isfield(loaded, 'fia_data')
    error('load_fia_file:notAFiaFile', ...
        '"%s" does not contain a variable called fia_data.', fullFileName);
end

fiaData = loaded.fia_data;      % load

end


