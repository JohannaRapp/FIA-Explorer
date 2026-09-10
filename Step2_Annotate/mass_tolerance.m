function tolerance = mass_tolerance(referenceMz, params)
%MASS_TOLERANCE  Matching window around a reference mass, in Da.
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp. Aug 2026

tolerance = max(params.massToleranceDa, ...
                params.massTolerancePpm * referenceMz(:) / 1e6);

end
