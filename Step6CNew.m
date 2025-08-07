function Step6CNew(inputDir, outputDir) % Input and output should be directories

    if ~exist(outputDir, 'dir')
        mkdir(outputDir); % Make destination folder
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get list of input .mat files

    for f = 1:length(files)
        fileName = files(f).name;
        inputPath = fullfile(inputDir, fileName);
        disp(['Processing file: ', inputPath]);

        % Load file and extract the struct within it
        fileStruct = load(inputPath);
        varNames = fieldnames(fileStruct);
        if isempty(varNames)
            error('No struct was found in the input file.');
        end
        subjectTag = varNames{1}; % ex. Subject_0604
        allSubjStruct = fileStruct.(subjectTag);

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
                condIdx = find(strcmp(locLabels, attendLabel));

                % Loop through all 25 possible combinations
                for j = 1:25
                    trigger = j;

                    % Create yes (_Y) and no (_N) versions of this trigger
                    yesTrig = ['trigger_' num2str(trigger) '_Y'];
                    noTrig  = ['trigger_' num2str(trigger) '_N'];

                    % Find the column number of this trigger in the location matrix
                    [~, trigColIdx] = find(locMatrix == trigger);

                    % Say which trigger is correct and incorrect at that location
                    if trigColIdx == condIdx
                        corrTrig = yesTrig;
                        incorrTrig = noTrig;
                    else
                        corrTrig = noTrig;
                        incorrTrig = yesTrig;
                    end

                    corrWeight = 0;
                    if isfield(condStruct, corrTrig) % If the correct answer was in the struct
                        correctStruct = condStruct.(corrTrig); % Structure with correct answers
                        corrFiles = fieldnames(correctStruct); % File names
                        summedData = zeros(63, 1051); % Initialize sum

                        % Compute weighted average across all files in that struct
                        for k = 1:length(corrFiles)
                            fileNameIn = corrFiles{k};
                            fileStruct = correctStruct.(fileNameIn);
                            dataWeight = fileStruct.num_files; % Weight by count
                            dataMatrix = fileStruct.epoch_avg; % Average data
                            summedData = summedData + dataMatrix * dataWeight;
                            corrWeight = corrWeight + dataWeight;
                        end

                        % Store weighted average and count
                        weightedStruct.(condition).(corrTrig).epoch_avg_trigger = summedData / corrWeight;
                        weightedStruct.(condition).(corrTrig).num_files_trigger = corrWeight;
                    end

                    % Sum weights of incorrect responses
                    incorrWeight = 0;
                    if isfield(condStruct, incorrTrig)
                        fieldsWrong = fieldnames(condStruct.(incorrTrig));
                        for k = 1:length(fieldsWrong)
                            incorrWeight = incorrWeight + condStruct.(incorrTrig).(fieldsWrong{k}).num_files;
                        end
                    end

                    % Only warn if not on the diagonal (triggers 1,7,13,19,25)
                    if incorrWeight > corrWeight && ~ismember(trigger, [1, 7, 13, 19, 25])
                        disp(['There were more incorrect than correct responses for ', ...
                            condition, ' ', yesTrig(1:end-2), ...
                            ' (Amount wrong: ', num2str(incorrWeight), ...
                            ', Amount right: ', num2str(corrWeight), ')']);
                    end
                end

            else % Passive condition, don't need to check for correctness
                for j = 1:length(triggerNames)
                    triggerName = triggerNames{j};
                    triggerStruct = condStruct.(triggerName);
                    dataFiles = fieldnames(triggerStruct);
                    summedWeight = 0;
                    summedData = zeros(63, 1051); % Initialize sum

                    % Weighted average of all files for this passive trigger
                    for k = 1:length(dataFiles)
                        fileStruct = triggerStruct.(dataFiles{k});
                        dataWeight = fileStruct.num_files;
                        dataMatrix = fileStruct.epoch_avg;
                        summedData = summedData + dataMatrix * dataWeight;
                        summedWeight = summedWeight + dataWeight;
                    end

                    % Save weighted average and number of contributing files
                    weightedStruct.(condition).(triggerName).epoch_avg_trigger = summedData / summedWeight;
                    weightedStruct.(condition).(triggerName).num_files_trigger = summedWeight;
                end
            end
        end

        % Wrap final struct in subject name with _6C
        outputWrapper = struct();
        newTag = [erase(subjectTag, '_6B') '_6C'];
        outputWrapper.(newTag) = weightedStruct;

        % Save to new file in outputDir
        outputPath = fullfile(outputDir, [newTag '.mat']);
        save(outputPath, '-struct', 'outputWrapper', '-v7.3');
        disp(['Saved to file: ', outputPath]);
    end
end
