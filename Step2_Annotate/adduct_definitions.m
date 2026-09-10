function adducts = adduct_definitions()
%ADDUCT_DEFINITIONS  Table of the ESI adducts this pipeline can annotate.
%
%   ADDUCTS = ADDUCT_DEFINITIONS() returns a table with one row per
%   supported adduct and the columns
%
%       name          adduct label, e.g. '[M+H]+'
%       polarity      "positive" or "negative"
%       nMolecules    how many neutral molecules form the ion (1, 2 or 3)
%       charge        absolute charge of the ion
%       massOffset    mass added per unit charge, in Da
%
%   The measured mass of an adduct is always
%
%       mz = (nMolecules * neutralMass) / charge + massOffset
%
%   Calling ADDUCT_DEFINITIONS with no output prints the table, which is a
%   convenient way to look up the exact spelling of an adduct name before
%   putting it into PARAMS.adductsPositive or PARAMS.adductsNegative.
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

% Monoisotopic masses of the charged species, in Da. These are ion masses,
% i.e. the electron has already been accounted for, which is why the proton
% is 1.007276 and not the 1.008 of a hydrogen atom.
PROTON = 1.007276;

% Each row is {name, polarity, nMolecules, charge, massOffset}.
%
% For a multiply charged ion the offset is the total added mass divided by
% the charge, because the whole expression is divided by the charge. For
% [M+2H]2+ that is (2 * 1.007276) / 2 = 1.007276, and for [M+H+Na]2+ it is
% (1.007276 + 22.989218) / 2 = 11.998247.

rows = {
% --- negative polarity -------------------------------------------------
    '[M]-',              'negative', 1, 1,   0            % radical anion
    '[M-H]-',            'negative', 1, 1,  -PROTON
    '[M-2H]2-',          'negative', 1, 2,  -PROTON
    '[M-3H]3-',          'negative', 1, 3,  -PROTON
    '[M-H2O-H]-',        'negative', 1, 1, -19.018390
    '[M+Na-2H]-',        'negative', 1, 1,  20.974666
    '[M+Cl]-',           'negative', 1, 1,  34.969402
    '[M+K-2H]-',         'negative', 1, 1,  36.948606
    '[M+FA-H]-',         'negative', 1, 1,  44.998201     % formic acid
    '[M+Hac-H]-',        'negative', 1, 1,  59.013851     % acetic acid
    '[M+Br]-',           'negative', 1, 1,  78.918885
    '[2M-H]-',           'negative', 2, 1,  -PROTON
    '[2M+FA-H]-',        'negative', 2, 1,  44.998201
    '[2M+Hac-H]-',       'negative', 2, 1,  59.013851
    '[3M-H]-',           'negative', 3, 1,  -PROTON

% --- positive polarity -------------------------------------------------
    '[M]+',              'positive', 1, 1,   0            % radical cation
    '[M+H]+',            'positive', 1, 1,   PROTON
    '[M+NH4]+',          'positive', 1, 1,  18.033823
    '[M+Na]+',           'positive', 1, 1,  22.989218     % CORRECTED, see below
    '[M+CH3OH+H]+',      'positive', 1, 1,  33.033489     % methanol
    '[M+K]+',            'positive', 1, 1,  38.963158
    '[M+ACN+H]+',        'positive', 1, 1,  42.033823     % acetonitrile
    '[M+2Na-H]+',        'positive', 1, 1,  44.971160
    '[M+IsoProp+H]+',    'positive', 1, 1,  61.065340     % isopropanol
    '[M+ACN+Na]+',       'positive', 1, 1,  64.015765
    '[M+2K-H]+',         'positive', 1, 1,  76.919040
    '[M+2ACN+H]+',       'positive', 1, 1,  83.060370
    '[M+IsoProp+Na+H]+', 'positive', 1, 1,  84.055110     % CORRECTED, see below
    '[M+2H]2+',          'positive', 1, 2,   PROTON
    '[M+H+NH4]2+',       'positive', 1, 2,   9.520550
    '[M+H+Na]2+',        'positive', 1, 2,  11.998247
    '[M+H+K]2+',         'positive', 1, 2,  19.985217
    '[M+ACN+2H]2+',      'positive', 1, 2,  21.520550     % CORRECTED, see below
    '[M+2Na]2+',         'positive', 1, 2,  22.989218
    '[M+2ACN+2H]2+',     'positive', 1, 2,  42.033823
    '[M+3ACN+2H]2+',     'positive', 1, 2,  62.547097
    '[M+3H]3+',          'positive', 1, 3,   PROTON
    '[M+2H+Na]3+',       'positive', 1, 3,   8.334590
    '[M+H+2Na]3+',       'positive', 1, 3,  15.661904
    '[2M+H]+',           'positive', 2, 1,   PROTON
    '[2M+NH4]+',         'positive', 2, 1,  18.033823
    '[2M+Na]+',          'positive', 2, 1,  22.989218
    '[2M+K]+',           'positive', 2, 1,  38.963158
    '[2M+ACN+H]+',       'positive', 2, 1,  42.033823
    '[2M+ACN+Na]+',      'positive', 2, 1,  64.015765
    };

adducts = table( ...
    rows(:, 1), ...
    string(rows(:, 2)), ...
    cell2mat(rows(:, 3)), ...
    cell2mat(rows(:, 4)), ...
    cell2mat(rows(:, 5)), ...
    'VariableNames', {'name', 'polarity', 'nMolecules', 'charge', 'massOffset'});

if nargout == 0
    disp(adducts);
    clear adducts
end

end
