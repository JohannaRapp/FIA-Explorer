function referenceList = get_adduct_masses(metaboliteDb, adductNames, polarity)
%GET_ADDUCT_MASSES  Expand a metabolite database into a list of ion masses.
%
%   REFERENCELIST = GET_ADDUCT_MASSES(METABOLITEDB, ADDUCTNAMES, POLARITY)
%   turns the neutral monoisotopic masses in METABOLITEDB into the m/z
%   values that would actually be measured, one entry per metabolite and
%   adduct combination. POLARITY is "positive" or "negative" (or 1 and 2,
%   the mode indices used throughout the pipeline).
%
%   METABOLITEDB is the db_annot variable stored in the files under
%   Databases/ and must provide the fields
%
%       mass       neutral monoisotopic mass, in Da
%       metNames   full metabolite name
%       metAbb     short abbreviation
%       kegg       KEGG identifier
%
%   REFERENCELIST is a table with one row per expected ion:
%
%       abbr        abbreviation with the adduct appended, e.g. 'glc[M-H]-'
%       MetName     full name with the adduct appended
%       ref_mass    expected m/z
%       kegg_id     KEGG identifier
%       adduct      adduct on its own, e.g. '[M-H]-'
%       dbRow       row of METABOLITEDB this entry came from
%
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

arguments
    metaboliteDb
    adductNames (1,:) cell
    polarity
end

% Accept either the mode index used by the pipeline or the polarity name.
if isnumeric(polarity)
    polarityNames = ["positive", "negative"];
    polarity = polarityNames(polarity);
else
    polarity = string(polarity);
end

neutralMass = double(metaboliteDb.mass(:));
metName     = metaboliteDb.metNames(:);
metAbbrev   = metaboliteDb.metAbb(:);
keggId      = metaboliteDb.kegg(:);

nMetabolites = numel(neutralMass);
knownAdducts = adduct_definitions();

% Build one block per adduct, then stack them. 
blocks = cell(numel(adductNames), 1);

for k = 1:numel(adductNames)
    adductName = adductNames{k};
    isMatch = strcmp(knownAdducts.name, adductName);

    if ~any(isMatch)
        error('get_adduct_masses:unknownAdduct', ...
            ['"%s" is not a known adduct. Run adduct_definitions to list ' ...
             'the supported names.'], adductName);
    end

    adduct = knownAdducts(isMatch, :);

    if adduct.polarity ~= polarity
        error('get_adduct_masses:wrongPolarity', ...
            'Adduct "%s" is a %s ion and cannot be used in %s polarity.', ...
            adductName, adduct.polarity, polarity);
    end

    % formula that covers every supported adduct. See
    % ADDUCT_DEFINITIONS for how nMolecules, charge and massOffset combine.
    ionMass = (adduct.nMolecules * neutralMass) / adduct.charge + adduct.massOffset;

    blocks{k} = table( ...
        strcat(metAbbrev, adductName), ...
        strcat(metName, adductName), ...
        ionMass, ...
        keggId, ...
        repmat({adductName}, nMetabolites, 1), ...
        (1:nMetabolites).', ...
        'VariableNames', {'abbr', 'MetName', 'ref_mass', 'kegg_id', 'adduct', 'dbRow'});
end

referenceList = vertcat(blocks{:});

end
