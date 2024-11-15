function sFiles = Step1(sFiles) 

    % Process: Band-pass:0.1Hz-100Hz
    sFiles = bst_process('CallProcess', 'process_bandpass', sFiles, [], ...
        'sensortypes', 'EEG', ...
        'highpass',    0.1, ...
        'lowpass',     100, ...
        'tranband',    0, ...
        'attenuation', 'strict', ...  % 60dB
        'ver',         '2019', ...  % 2019
        'mirror',      0, ...
        'read_all',    0);

    % Process: Notch filter: 60Hz
    sFiles = bst_process('CallProcess', 'process_notch', sFiles, [], ...
        'sensortypes', 'MEG, EEG', ...
        'freqlist',    60, ...
        'cutoffW',     1, ...
        'useold',      0, ...
        'read_all',    0);

    % Process: Duplicate / merge events
    sFiles = bst_process('CallProcess', 'process_evt_merge', sFiles, [], ...
        'evtnames', '0', ...
        'newname',  '0_bad', ...
        'delete',   0);

    % Process: Convert to extended event
    sFiles = bst_process('CallProcess', 'process_evt_extended', sFiles, [], ...
        'eventname',  '0_bad', ...
        'timewindow', [0, 10]);
    
    % Process: Detect eye blinks
    sFiles = bst_process('CallProcess', 'process_evt_detect_eog', sFiles, [], ...
        'channelname', 'AF7', ...
        'timewindow',  [], ...
        'eventname',   'blink');


end

