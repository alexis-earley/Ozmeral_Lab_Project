function sFiles = Step4(sFiles, TableName) 

    FullTable = (readtable(TableName));
    TableHead = FullTable{1,:};
    
    PrevSubjNum = -1; % No previous subject
    sFilesTemp = [];
    testvar = 1;
    Meaning = '';
    
    SizeFiles = length(sFiles); % Iterate through files
    for i = 1:SizeFiles
        
        CurrFile = sFiles(i);
        SubjName = CurrFile.SubjectName; % Get subject name
        SubjNum = str2double(char(regexp(SubjName,'[0-9]','match'))); % Get subject number
        
        if (PrevSubjNum ~= SubjNum) % NIf it is a new subject
            TableIdx = find(TableHead == SubjNum); % Returns index of that subject number
            SubjCol = FullTable{(2:end),TableIdx}; % Returns list of subject info
            j = 1; % Index in column
            Block = 0; % Start a new block
        end
    
        TableNum = SubjCol(j); % Read the first value 
        % Each value corresponds to a condition
    
        if isnan(TableNum)
            disp('Error: Extra sfiles provided.');
        end
    
        if (TableNum == 5) % Indicates a new block
            Block = Block + 1;
            j = j + 1; % Check
            TableNum = SubjCol(j);
            SubBlock = 1;
        end
    
        if (TableNum == 0) % Indicates the file was bad and sjould be deleted
            bst_process('CallProcess', 'process_delete', CurrFile, [], ...
            'target', 2);  % Delete folder
    
            j = j + 1; % Move onto next index
            PrevSubjNum = SubjNum; % Move onto next subject
    
            continue;
        end
    
        if (TableNum == 1)
            Meaning = 'Quiet_Passive';
        elseif (TableNum == 2)
            Meaning = 'Noise_Passive';
        elseif (TableNum == 3)
            Meaning = 'Noise_Attend30';
        elseif (TableNum == 4)
            Meaning = 'Noise_Attend60';
        end
    
        Name = ['Block', num2str(Block), '_', num2str(SubBlock), '_', Meaning]; % Create name of new file
    
        % Process: Import MEG/EEG: Events
        CurrFile = bst_process('CallProcess', 'process_import_data_event', CurrFile, [], ...
            'subjectname',   SubjName, ...
            'condition',     Name, ...
            'eventname',     '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,50,60,1_N,2_N,3_N,4_N,5_N,6_N,7_N,8_N,9_N,10_N,11_N,12_N,13_N,14_N,15_N,16_N,17_N,18_N,19_N,20_N,21_N,22_N,23_N,24_N,25_N,1_Y,2_Y,3_Y,4_Y,5_Y,6_Y,7_Y,8_Y,9_Y,10_Y,11_Y,12_Y,13_Y,14_Y,15_Y,16_Y,17_Y,18_Y,19_Y,20_Y,21_Y,22_Y,23_Y,24_Y,25_Y', ...
            'timewindow',    [], ...
            'epochtime',     [-0.1, 2], ...
            'createcond',    0, ...
            'ignoreshort',   1, ...
            'usectfcomp',    1, ...
            'usessp',        1, ...
            'freq',          [], ...
            'baseline',      [-0.1, -0.002], ...
            'blsensortypes', 'EEG');
    
        % Process: Remove linear trend: [-100ms,2000ms]
        CurrFile = bst_process('CallProcess', 'process_detrend', CurrFile, [], ...
            'timewindow',  [-0.1, 2], ...
            'sensortypes', 'EEG', ...
            'overwrite',   1);
    
    
        sFilesTemp = [sFilesTemp, CurrFile]; % Create a temporary list of sFiles
    
        j = j + 1; % Move to next number in subject info list
        PrevSubjNum = SubjNum; % Move onto next subject
        SubBlock = SubBlock + 1; % Move to next subblock
       
    end
    
    sFiles = sFilesTemp; % Create final sFiles list

end
