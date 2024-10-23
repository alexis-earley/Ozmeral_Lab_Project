function sFiles = Step4(sFiles, TableName) 

    FullTable = (readtable(TableName));
    % FullTable = (readtable('Updated_Table_8_25_24.csv'));
    TableHead = FullTable{1,:};
    
    PrevSubjNum = -1; % No previous subject
    sFilesTemp = [];
    testvar = 1;
    Meaning = '';
    
    SizeFiles = length(sFiles);
    for i = 1:SizeFiles
        
        CurrFile = sFiles(i);
        SubjName = CurrFile.SubjectName;
        SubjNum = str2double(char(regexp(SubjName,'[0-9]','match')));
        
        if (PrevSubjNum ~= SubjNum) % New Subject
            TableIdx = find(TableHead == SubjNum); % Returns index of that subject number
            SubjCol = FullTable{(2:end),TableIdx}; % Returns list of subject info
            j = 1; % Index in column
            Block = 0;
        end
    
        TableNum = SubjCol(j);
    
        if isnan(TableNum)
            disp('Error: Extra sfiles provided.');
        end
    
        if (TableNum == 5)
            Block = Block + 1;
            j = j + 1; % Check
            TableNum = SubjCol(j);
            SubBlock = 1;
        end
    
        if (TableNum == 0)
            bst_process('CallProcess', 'process_delete', CurrFile, [], ...
            'target', 2);  % Delete folder
    
            j = j + 1;
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
    
        Name = ['Block', num2str(Block), '_', num2str(SubBlock), '_', Meaning];
    
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
    
    
        sFilesTemp = [sFilesTemp, CurrFile];
    
        j = j + 1; % Move to next number in subject info list
        PrevSubjNum = SubjNum; % Move onto next subject
        SubBlock = SubBlock + 1;
       
    end
    
    sFiles = sFilesTemp;

end


%{

% Step4_new(sFiles,FullTable);

% function sFiles = Step4_new(sFiles, FullTable) 

% load('SAA_Multiple_Subjects_CurrentVariables_8_25_24_Step_3.mat')

FullTable = (readtable('Updated_Table_8_25_24.csv'));

    SubjData = table2array(FullTable(1,:));
    sFilesTemp = [];
    TypeFiles = class(sFiles);

    % PrevSubj = 'Subject_1071'; %FIXME
    i = 1;

     while i < length(sFiles)

         CurrFile = sFiles(i);
         
         if isequal(TypeFiles,'cell')
             SubjElement = CurrFile{i};
             CurrSubj = SubjElement(1:12);
         elseif isequal(TypeFiles,'struct')
             CurrSubj = CurrFile.SubjectName;
         end

        SubjNum = str2double(char(regexp(CurrSubj,'[0-9]','match')));
        SubjIndx = find(SubjData == SubjNum);
        IndxTable = table2array(FullTable(:,SubjIndx));
        LengthColumn = length(IndxTable);

        Letters = char(97:122);
        Block = 0;
        LetterIndx = 1;
        CurrLett = 'a';
        ElementIndx = 1;
        Element = 1;
        BlockValue = 1;

        while (~isnan(Element) && (ElementIndx < LengthColumn)) % && i < length(sFiles)) 

            i = i+1;
            ElementIndx = ElementIndx + 1;
            
            Element = IndxTable (ElementIndx);
            switch Element
                case 0
                    disp('Delete file');
                    % name = bst_process('CallProcess', 'process_delete', CurrFile, [], 'target', 2);  % Delete folders
                    continue;
                case 1
                    Meaning = 'Quiet_Passive';
                case 2
                    Meaning = 'Noise_Passive';
                case 3
                    Meaning = 'Noise_Attend30';
                case 4
                    Meaning = 'Noise_Attend60';
                case 5
                    Block = Block + 1;
                    BlockValue = 1;
                    CurrLett = 'a';
                    continue;
            end

            Description = [Meaning, '_Block_', num2str(Block), '_', CurrLett, '_'] % TODO: Change to be more descriptive of date, etc.

            % PUT PROCESSES AND NEW SFILES HERE

            % sFilesTemp = [sFilesTemp, sFiles([i])];

            % NonDeletes = NonDeletes + 1;

            if (mod(BlockValue, 4) == 0)
                BlockValue = BlockValue + 1;
                LetterIndx = LetterIndx + 1;
                CurrLett = Letters(LetterIndx);
            end   

        end
    
           

            %{

            % Process: Import MEG/EEG: Events
            sFile = bst_process('CallProcess', 'process_import_data_event', CurrFile, [], ...
                'subjectname',   CurrSubj, ...
                'condition',     Description, ...
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
            sFile = bst_process('CallProcess', 'process_detrend', sFile, [], ...
                'timewindow',  [-0.1, 2], ...
                'sensortypes', 'EEG', ...
                'overwrite',   1);

            %}

     end

     % sFiles = sFilesTemp;

    %{
    
    OrdersTable = FullTable(:,3:6); % Change csv to not have "Include" column
    Orders = table2array(OrdersTable);
    ConditionNames = FullTable.Properties.VariableNames;
    
    PrevFileSubj = "";
    sFilesTemp = [];
    
    for i = 1:length(sFiles) 
        CurrFile = sFiles(i);
        CurrSubj = CurrFile.SubjectName;
    
        if CurrSubj == PrevFileSubj
        else
            FileIndex = 1;
            SubjNum = str2double(char(regexp(CurrSubj,'[0-9]','match')));
            for j = 1:length(SubjData)
                MaybeMatch = SubjData(j);
                if MaybeMatch == SubjNum
                    CurrOrder = Orders(j,:);
    
                    SubjOrders = {};
                    for k = 1:4
                        Meaning = Order2Meaning(find(CurrOrder == k));
                        SubjOrders = [SubjOrders, Meaning];
                    end
                end
            end
        end
    
        Block = floor((FileIndex-1)/4) + 1;
        Remainder = mod(FileIndex,4);
    
        if Remainder ~= 0
            Condition = SubjOrders{Remainder};
        else
            Condition = SubjOrders{4};
        end
    
        Description = [Condition, '_Block_', num2str(Block)];
    
       

        % Process: Import MEG/EEG: Events
        sFile = bst_process('CallProcess', 'process_import_data_event', CurrFile, [], ...
            'subjectname',   CurrSubj, ...
            'condition',     Description, ...
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
        sFile = bst_process('CallProcess', 'process_detrend', sFile, [], ...
            'timewindow',  [-0.1, 2], ...
            'sensortypes', 'EEG', ...
            'overwrite',   1);
    
    
        sFilesTemp = [sFilesTemp, sFile];

        FileIndex = FileIndex + 1;
        PrevFileSubj = CurrSubj;
    
    end
    
    sFiles = sFilesTemp;
    


    function Meaning = Order2Meaning(Order)
    
        switch Order
            case 0
                Meaning = '';
            case 1
                Meaning = 'Quiet_Passive';
            case 2
                Meaning = 'Noise_Passive';
            case 3
                Meaning = 'Noise_Attend30';
            case 4
                Meaning = 'Noise_Attend60';
        end
    
    end



end

    %}

     %}