function sFiles = Step3_New(sFiles) 

    % Process: Select file names with tag: _notch
    sFiles = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
        'tag',    'notch', ...
        'search', 2, ...  % Search the file names
        'select', 1);  % Select only the files with the tag
    
    sFilesTemp = [];
    
    for i = 1:length(sFiles)
    
        sFile = sFiles(i);
    
        % Process: Combine stim/response
        sFile = bst_process('CallProcess', 'process_evt_combine', sFile, [], ...
            'combine', ['1_Y, ignore, 1, 50 ' 10 '1_N, ignore, 1, 60 ' 10 '2_Y, ignore, 2, 50 ' 10 '2_N, ignore, 2, 60' 10 '3_Y, ignore, 3, 50 ' 10 '3_N, ignore, 3, 60' 10 '4_Y, ignore, 4, 50 ' 10 '4_N, ignore, 4, 60' 10 '5_Y, ignore, 5, 50 ' 10 '5_N, ignore, 5, 60' 10 '6_Y, ignore, 6, 50 ' 10 '6_N, ignore, 6, 60 ' 10 '7_Y, ignore, 7, 50 ' 10 '7_N, ignore,7, 60' 10 '8_Y, ignore, 8, 50 ' 10 '8_N, ignore, 8, 60' 10 '9_Y, ignore,9, 50 ' 10 '9_N, ignore, 9, 60' 10 '10_Y, ignore, 10, 50 ' 10 '10_N, ignore,10, 60' 10 '11_Y, ignore,11, 50 ' 10 '11_N, ignore, 11, 60 ' 10 '12_Y, ignore, 12, 50 ' 10 '12_N, ignore,12, 60' 10 '13_Y, ignore, 13, 50 ' 10 '13_N, ignore, 13, 60' 10 '14_Y, ignore, 14, 50 ' 10 '14_N, ignore, 14, 60' 10 '15_Y, ignore, 15, 50 ' 10 '15_N, ignore, 15, 60' 10 '16_Y, ignore, 16, 50 ' 10 '16_N, ignore, 16, 60 ' 10 '17_Y, ignore, 17, 50 ' 10 '17_N, ignore, 17, 60' 10 '18_Y, ignore, 18, 50 ' 10 '18_N, ignore, 18, 60' 10 '19_Y, ignore, 19, 50 ' 10 '19_N, ignore, 19, 60' 10 '20_Y, ignore, 20, 50 ' 10 '20_N, ignore,20, 60' 10 '21_Y, ignore,21, 50 ' 10 '21_N, ignore, 21, 60 ' 10 '22_Y, ignore, 22, 50 ' 10 '22_N, ignore, 22, 60' 10 '23_Y, ignore, 23, 50 ' 10 '23_N, ignore, 23, 60' 10 '24_Y, ignore, 24, 50 ' 10 '24_N, ignore, 24, 60' 10 '25_Y, ignore, 25, 50 ' 10 '25_N, ignore, 25, 60'], ...
            'dt',      2);

        % Process: Delete events
        sFile = bst_process('CallProcess', 'process_evt_delete', sFile, [], ...
            'eventname', '0_combined');
        
        % Process: Group by name
        sFile = bst_process('CallProcess', 'process_evt_groupname', sFile, [], ...
            'combine', '0_combined = 0,0', ...
            'dt',      0.45, ...
            'order',   'last', ...  % Last
            'delete',  0);

        % Process: Split Raw File
        sFile = bst_process('CallProcess', 'process_split_raw_file', sFile, [], ...
            'eventname',       '__', ...
            'keepbadsegments', 0);
    
        sFilesTemp = [sFilesTemp, sFile];
    
    end
    
    sFiles = sFilesTemp;

end