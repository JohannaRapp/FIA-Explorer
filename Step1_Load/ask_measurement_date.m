function measurementDate = ask_measurement_date()
%ASK_MEASUREMENT_DATE  Optionally ask the user when the samples were measured.
%
%   MEASUREMENTDATE = ASK_MEASUREMENT_DATE() opens a yes/no dialog and, if
%   the user agrees, prompts for the date on which the data were acquired.
%   The result is a datetime, or NaT if the user declined or cancelled.
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

measurementDate = NaT;

wantsDate = questdlg('Do you want to add a measurement date to the FIA file?', ...
    'Timestamp for FIA file', 'Yes', 'No', 'Yes');

if ~strcmp(wantsDate, 'Yes')
    return
end

while true
    answer = inputdlg({'Date of measurement (dd.mm.yyyy)'}, 'Measurement date', ...
        [1 40], {char(datetime('today', 'Format', 'dd.MM.yyyy'))});

    if isempty(answer)
        return      % dialog cancelled: leave the date unset
    end

    try
        measurementDate = datetime(strtrim(answer{1}), 'InputFormat', 'dd.MM.yyyy');
        return
    catch
        uiwait(msgbox( ...
            sprintf('"%s" is not a valid date. Please use the format dd.mm.yyyy, for example %s.', ...
            strtrim(answer{1}), char(datetime('today', 'Format', 'dd.MM.yyyy'))), ...
            'Invalid date', 'warn', 'modal'));
    end
end

end
