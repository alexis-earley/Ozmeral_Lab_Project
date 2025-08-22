
%TODO: Look through ignored files and make sure we're not concerned
%TODO: Opposite, see if there are files on excel that aren't on Brainstorm X
sFileNames = {};
for i = 1:length(sFiles)
    sFile = sFiles(i);
    sFileName = sFile.Condition;
    sFileName = sFileName(5:end);
    sFileNames{end + 1} = sFileName;
end

sFileNames = string(sFileNames);

ProtocolPath = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Brainstorm_db\Paper_Data_OHI_01_27_2025\data';
TableName = ('OHI_File_Name_Table.csv');
FullTable = (table2cell(readtable(TableName, 'Delimiter', ',')));
[numRows, numCols] = size(FullTable);


for row = 1:numRows

    FullRow = FullTable(row,:);

    %{
    Subject = num2str(FullRow{1});
    if length(Subject) == 3
        Subject = ['0' Subject]; % Prepend '0' to the string
    end
    %}

    tFileName = FullRow{2};

    Aid = FullRow{3};
    if strcmpi(Aid, 'Aided') 
        Aid = FullRow{4};
    end

    Cond = FullRow{5};
    Side = FullRow{6};
    Passive = -1;
    if strcmpi(Cond, 'Passive_Q') 
        Cond = 'PassiveQ';
        Passive = 1;
    elseif strcmpi(Cond, 'Passive_N') 
        Cond = 'PassiveN';
        Passive = 1;
    elseif strcmpi(Cond, 'Attend_30') 
        Cond = ['Attend30', Side];  
        Passive = 0;
    elseif strcmpi(Cond, 'Attend_60') 
        Cond = ['Attend60', Side];
        Passive = 0;
    end
    
    % TotalName = [Subject, '_', Aid, '_', Cond, '_', Side];
    TotalName = [Aid, '_', Cond];

    index = find(ismember(sFileNames, tFileName));

    sFile = sFiles(index);

    %if ~isequal(sFile)

    if isempty(sFile)
        continue;
    end

    % Get file events
    %z = load((fullfile(ProtocolPath,sFiles([i]).FileName)));
    z = load((fullfile(ProtocolPath,sFile.FileName)));
    eventLabels = {z.F.events.label};

    if isempty(eventLabels)
        error(['No events present in file: ', tFileName]);
    end

    baseEvents = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', ...
              '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', ...
              '21', '22', '23', '24', '25'};
    
    % Loop through each target label
    for i = 1:length(baseEvents)
        labelToCheck = baseEvents{i};
        
        % Find index of the matching label
        idx = find(strcmp(eventLabels, labelToCheck));
        
        if ~isempty(idx)  % If label exists
            % Check if at least one corresponding times field is non-empty
            if ~any(~cellfun(@isempty, {z.F.events(idx).times}))
                %foundBaseEvent = true;
                %break; 
                
                 error(['This file is missing events: ', tFileName]);

            end
        end
    end

    targetEvents = {'1_N', '2_N', '3_N', '4_N', '5_N', '6_N', '7_N', '8_N', '9_N', '10_N', ...
            '11_N', '12_N', '13_N', '14_N', '15_N', '16_N', '17_N', '18_N', '19_N', '20_N', ...
            '21_N', '22_N', '23_N', '24_N', '25_N', '1_Y', '2_Y', '3_Y', '4_Y', '5_Y', ...
            '6_Y', '7_Y', '8_Y', '9_Y', '10_Y', '11_Y', '12_Y', '13_Y', '14_Y', '15_Y', ...
            '16_Y', '17_Y', '18_Y', '19_Y', '20_Y', '21_Y', '22_Y', '23_Y', '24_Y', '25_Y'};

    % Flag to indicate success
    foundValidEvent = false;
    
    % Loop through each target label
    for i = 1:length(targetEvents)
        labelToCheck = targetEvents{i};
        
        % Find index of the matching label
        idx = find(strcmp(eventLabels, labelToCheck));
        
        if ~isempty(idx)  % If label exists
            % Check if at least one corresponding times field is non-empty
            if any(~cellfun(@isempty, {z.F.events(idx).times}))
                foundValidEvent = true;
                break; 
            end
        end
    end
    
    if foundValidEvent && Passive
        error(['This passive event appears to actually be active: ', tFileName]);
    end

    if ~foundValidEvent && ~Passive
        error(['This active event appears to actually be passive: ', tFileName]);
    end

    % Process: Set name
    sFiles(index) = bst_process('CallProcess', 'process_set_comment', sFiles(index), [], ...
    'tag',           TotalName, ...
    'isindex',       1);
   
end

tFileNames = FullTable(:,2);
[tf, loc] = (ismember(sFileNames, string(tFileNames)));
missingIndexes = find(~tf);

for missIdx = 1:length(missingIndexes)
    sFile = sFiles(missingIndexes(missIdx));
    % Process: Set name
    sFile = bst_process('CallProcess', 'process_set_comment', sFile, [], ...
    'tag',           'Ignore_File', ...
    'isindex',       1);
end

[tf, loc] = (ismember(string(tFileNames), sFileNames));
missingIndexes = find(~tf);
missingFiles = tFileNames(missingIndexes);
disp('The following files from the table were not found in Brainstorm:')
disp(missingFiles);
