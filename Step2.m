function sFiles = Step2(sFiles) 

% Select only "notch" files
sFiles = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
    'tag',    'notch', ...
    'search', 2, ...  % Search the file names
    'select', 1);  % Select only the files with the tag

% Process: Re-reference EEG
sFiles = bst_process('CallProcess', 'process_eegref', sFiles, [], ...
    'eegref',      'AVERAGE', ...
    'sensortypes', 'EEG');

% Process: SSP EOG: blink
sFiles = bst_process('CallProcess', 'process_ssp_eog', sFiles, [], ...
    'eventname',   'blink', ...
    'sensortypes', 'EEG', ...
    'usessp',      1, ...
    'select',      1);

end