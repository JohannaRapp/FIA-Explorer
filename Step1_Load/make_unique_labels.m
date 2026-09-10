function labels = make_unique_labels(sampleNames, positions)
%MAKE_UNIQUE_LABELS  Disambiguate repeated sample names with plate positions.
%
%   LABELS = MAKE_UNIQUE_LABELS(SAMPLENAMES, POSITIONS) returns one label
%   per sample, guaranteed unique, for use as Excel column headings and
%   MATLAB table variable names.
%
%   A sample name is everything before the second-to-last underscore of the
%   raw file name, so two wells with the same sample share it: both
%   "aroC_P6-A1_pos.mzXML" and "aroC_P6-A2_pos.mzXML" are sample "aroC".
%   Where that happens the plate position is appended, giving "aroC_P6-A1"
%   and "aroC_P6-A2".
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

arguments
    sampleNames cell
    positions cell
end

labels = sampleNames(:);

if isempty(labels)
    return
end

positions = positions(:);

[~, ~, groupIndex] = unique(labels);
isRepeated = ismember(groupIndex, find(accumarray(groupIndex, 1) > 1));

labels(isRepeated) = strcat(labels(isRepeated), '_', positions(isRepeated));

if any(isRepeated)
    warning('make_unique_labels:duplicateSampleNames', ...
        ['%d files share a sample name with another file. Their plate ' ...
         'position was appended to keep the export column headings unique.'], ...
        sum(isRepeated));
end

% Guard against the remaining corner case of two files that agree in both
% sample name and position.
labels = matlab.lang.makeUniqueStrings(labels);

end
