function Step6C(inputFile, outputFile) % Input and output should be files

% Creates struct where each trigger is a weighted average of all matricies

    % Load file and extract the struct within it
    fileStruct = load(inputFile);
    disp(['Loaded file: ', inputFile]);

    varNames = fieldnames(fileStruct);
    if isempty(varNames)
        error('No struct was found in the input file.');
    end
    allSubjStruct = fileStruct.(varNames{1}); % Has the info for all subjects mixed into one struct

    weightedStruct = struct(); % Initialize struct to hold weighted averages

    % Define locMatrix reflecting triggers 1 - 25
    %           To 60L: To 30L: To 0:   To 30R: To 60R:         
    % From 60L: 1       2       3       4       5
    % From 30L: 6       7       8       9       10
    % From 0:   11      12      13      14      15
    % From 30R: 16      17      18      19      20
    % From 60R: 21      22      23      24      25
    locMatrix = reshape(1:25, [5, 5])'; 

    % Label columns of location matrix (determine correct responses)
    locLabels = {'60L', '30L', '0', '30R', '60R'};

    conditions = fieldnames(allSubjStruct); % Like Attend30L, PassiveN
    for i = 1:length(conditions)
        condition = conditions{i};
        condStruct = allSubjStruct.(condition);
        triggerNames = fieldnames(condStruct);

        % See if this is an active condition
        isActiveCond = strncmp(condition, 'Attend', 6);

        if isActiveCond
            
            % Get index of location label (like 30L) in earlier cell array
            attendLabel = condition(7:end);
            condIdx = find(strcmp(locLabels, attendLabel)); % Ex. 2 for 30L

            % Loop through all 25 possible combinations
            for j = 1:25
                
                trigger = j;

                % Create yes (_Y) and no (_N) versions of this trigger
                yesTrig = ['trigger_' num2str(trigger) '_Y']; % Ex. trigger_25_Y
                noTrig = ['trigger_' num2str(trigger) '_N']; % Ex. trigger_25_N 

                % Find the column number of this trigger in the location matrix
                [~, trigColIdx] = find(locMatrix == trigger); % Ex. 5 for trigger 25

                % Say which trigger is correct and incorrect at that location
                if trigColIdx == condIdx
                    corrTrig = yesTrig;
                    incorrTrig = noTrig;
                else
                    corrTrig = noTrig;
                    incorrTrig = yesTrig;
                end

                corrWeight = 0;
                if isfield(condStruct, corrTrig) % If the correct answer (ex. trigger_25_N) was in the struct 
                    correctStruct = condStruct.(corrTrig); % Structure with correct answers
                    corrFiles = fieldnames(correctStruct); % Ex. EOR21_Aim1_OHI_604_2021_06_03_13_45_55_band_notch_5
                    
                    summedData = zeros(63, 1051); % Exmpy data matrix, to be changed

                    % Compute weighted average across all files in that struct
                    for k = 1:length(corrFiles) 
                        fileName = corrFiles{k};
                        fileStruct = correctStruct.(fileName);
                        dataWeight = fileStruct.num_files; % Number of files that contributed
                        dataMatrix = fileStruct.epoch_avg; % Current average

                        % Weighted sum of all matrices
                        summedData = summedData + dataMatrix * dataWeight;  
                        corrWeight = corrWeight + dataWeight; % Make new value to track number of contributing files
                    end

                    % Store weighted average and count of contributing files
                    weightedStruct.(condition).(corrTrig).epoch_avg_trigger = summedData / corrWeight;
                    weightedStruct.(condition).(corrTrig).num_files_trigger = corrWeight;
                end

                % 
                incorrWeight = 0;
                if isfield(condStruct, incorrTrig) % Ex. trigger_25_Y if correct was trigger_25_N
                    fieldsWrong = fieldnames(condStruct.(incorrTrig)); % File names in incorrect struct
                    for k = 1:length(fieldsWrong)
                        incorrWeight = incorrWeight + condStruct.(incorrTrig).(fieldsWrong{k}).num_files;
                    end
                end

                if incorrWeight > corrWeight
                    disp(['There were more incorrect than correct responses for ', condition, ' ', yesTrig(1:end-2), ...
                        ' (Amount wrong: ', num2str(incorrWeight), ', Amount right: ', num2str(rightCount), ')']);
                end
            end

        else % Passive condition, don't need to check for correctness
            for j = 1:length(triggerNames)
                triggerName = triggerNames{j};
                triggerStruct = condStruct.(triggerName);
                dataFiles = fieldnames(triggerStruct);
                summedWeight = 0;
                summedData = zeros(63, 1051); % Exmpy data matrix, to be changed

                % Weighted average of all files for this passive trigger
                for k = 1:length(dataFiles)
                    fileStruct = triggerStruct.(dataFiles{k});
                    dataWeight = fileStruct.num_files;
                    dataMatrix = fileStruct.epoch_avg;
                    summedData = summedData + dataMatrix * dataWeight;
                    summedWeight = summedWeight + dataWeight;
                end

                % Save weighted average and number of contributing files
                weightedStruct.(condition).(triggerName).epoch_avg_trigger = summedData / corrWeight;
                weightedStruct.(condition).(triggerName).num_files_trigger = corrWeight;
            end
        end
    end

    % Save the final weighted struct to the specified output file
    save(outputFile, 'weightedStruct');
    disp(['Saved to file: ', outputFile]);
end
