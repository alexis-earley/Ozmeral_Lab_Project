function Step6CNew2(inputDir, outputDir) % Input and output should be directories

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
        locMatrix = reshape(1:25, [5, 5])'; 
        locLabels = {'60L', '30L', '0', '30R', '60R'};

        conditions = fieldnames(allSubjStruct); % Like Attend30L, PassiveN
        for i = 1:length(conditions)
            condition = conditions{i};
            condStruct = allSubjStruct.(condition);
            triggerNames = fieldnames(condStruct);
            isActiveCond = strncmp(condition, 'Attend', 6);

            if isActiveCond
                attendLabel = condition(7:end);
                condIdx = find(strcmp(locLabels, attendLabel));

                for j = 1:25
                    trigger = j;
                    yesTrig = ['trigger_' num2str(trigger) '_Y'];
                    noTrig  = ['trigger_' num2str(trigger) '_N'];

                    [~, trigColIdx] = find(locMatrix == trigger);
                    if trigColIdx == condIdx
                        corrTrig = yesTrig;
                        incorrTrig = noTrig;
                    else
                        corrTrig = noTrig;
                        incorrTrig = yesTrig;
                    end

                    conds = fieldnames(allSubjStruct);
                    triggerNames = fieldnames(allSubjStruct.(conds{1}));
                    blocks = fieldnames(allSubjStruct.(conds{1}).(triggerNames{1}));
                    dataFile1 = allSubjStruct.(conds{1}).(triggerNames{1}).(blocks{1}).epoch_avg;

                    [row, col] = size(dataFile1);

                    corrWeight = zeros(row, 1);
                    summedData = zeros(row, col);

                    if isfield(condStruct, corrTrig)
                        correctStruct = condStruct.(corrTrig);
                        corrFiles = fieldnames(correctStruct);

                        for k = 1:length(corrFiles)
                            fileNameIn = corrFiles{k};
                            fileStruct = correctStruct.(fileNameIn);
                            weightVec = fileStruct.num_files; % 63x1 matrix
                            dataMatrix = fileStruct.epoch_avg;
                            summedData = summedData + dataMatrix .* weightVec;
                            corrWeight = corrWeight + weightVec;
                        end

                        % Avoid divide-by-zero by replacing 0 with NaN then backfill
                        avgMatrix = summedData ./ corrWeight;
                        avgMatrix(isnan(avgMatrix)) = 0;

                        weightedStruct.(condition).(corrTrig).epoch_avg = avgMatrix;
                        weightedStruct.(condition).(corrTrig).num_files = corrWeight;
                    end

                    incorrWeight = 0;
                    if isfield(condStruct, incorrTrig)
                        fieldsWrong = fieldnames(condStruct.(incorrTrig));
                        for k = 1:length(fieldsWrong)
                            fieldW = fieldsWrong{k};
                            thisWeight = condStruct.(incorrTrig).(fieldW).num_files;
                            incorrWeight = incorrWeight + sum(thisWeight); % Sum total weight
                        end
                    end

                    if sum(corrWeight) < incorrWeight && ~ismember(trigger, [1, 7, 13, 19, 25])
                        disp(['There were more incorrect than correct responses for ', ...
                            condition, ' ', yesTrig(1:end-2), ...
                            ' (Wrong: ', num2str(incorrWeight), ...
                            ', Right: ', num2str(sum(corrWeight)), ')']);
                    end
                end

            else % Passive condition
                for j = 1:length(triggerNames)
                    triggerName = triggerNames{j};
                    triggerStruct = condStruct.(triggerName);
                    dataFiles = fieldnames(triggerStruct);

                    blockName = dataFiles{1};
                    dataMatrix = triggerStruct.(blockName).epoch_avg;

                    [row, col] = size(dataMatrix);

                    summedWeight = zeros(row, 1);
                    summedData = zeros(row, col);

                    for k = 1:length(dataFiles)
                        fileStruct = triggerStruct.(dataFiles{k});
                        weightVec = fileStruct.num_files; % 63x1
                        dataMatrix = fileStruct.epoch_avg;
                        summedData = summedData + dataMatrix .* weightVec;
                        summedWeight = summedWeight + weightVec;
                    end

                    avgMatrix = summedData ./ summedWeight;
                    avgMatrix(isnan(avgMatrix)) = 0;

                    weightedStruct.(condition).(triggerName).epoch_avg = avgMatrix;
                    weightedStruct.(condition).(triggerName).num_files = summedWeight;
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