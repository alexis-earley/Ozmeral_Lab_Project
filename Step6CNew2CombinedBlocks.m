function Step6CNew2CombinedBlocks(inputDir, outputDir)
% Collapses all block iterations across triggers into a single entry
% per (blockName, condition) combo — used when blocks are condition-specific.
% Output field order is sorted by block number and iteration.

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    locMatrix = reshape(1:25, [5, 5])';
    locLabels = {'60L', '30L', '0', '30R', '60R'};

    for f = 1:length(files)
        fileName = files(f).name;
        inputPath = fullfile(inputDir, fileName);
        disp(['Processing file: ', inputPath]);

        fileStruct = load(inputPath);
        varNames = fieldnames(fileStruct);
        subjectTag = varNames{1};
        subjData = fileStruct.(subjectTag);
        combinedStruct = struct();

        condList = fieldnames(subjData);
        for c = 1:length(condList)
            condition = condList{c};
            if ~isstruct(subjData.(condition)), continue; end
            isActiveCond = startsWith(condition, 'Attend');
            triggerList = fieldnames(subjData.(condition));

            if isActiveCond
                attendLabel = condition(7:end);
                condIdx = find(strcmp(locLabels, attendLabel));
            end

            % Get all block labels for correct triggers
            allBlockLabels = {};
            for t = 1:length(triggerList)
                trigger = triggerList{t};

                if isActiveCond
                    trigNum = sscanf(trigger, 'trigger_%d');
                    [~, trigCol] = find(locMatrix == trigNum);
                    isCorrect = (trigCol == condIdx);
                    isYes = endsWith(trigger, '_Y');
                    if xor(isYes, isCorrect), continue; end
                end

                if ~isstruct(subjData.(condition).(trigger)), continue; end
                blockList = fieldnames(subjData.(condition).(trigger));
                allBlockLabels = [allBlockLabels; blockList(:)];
            end

            uniqueBlocks = unique(allBlockLabels);

            for b = 1:length(uniqueBlocks)
                blockName = uniqueBlocks{b};
                sumMat = zeros(63, 1051);
                sumWeights = zeros(63, 1);

                for t = 1:length(triggerList)
                    trigger = triggerList{t};

                    if isActiveCond
                        trigNum = sscanf(trigger, 'trigger_%d');
                        [~, trigCol] = find(locMatrix == trigNum);
                        isCorrect = (trigCol == condIdx);
                        isYes = endsWith(trigger, '_Y');
                        if xor(isYes, isCorrect), continue; end
                    end

                    if isfield(subjData.(condition).(trigger), blockName)
                        blockStruct = subjData.(condition).(trigger).(blockName);
                        sumMat = sumMat + blockStruct.epoch_avg .* blockStruct.num_files;
                        sumWeights = sumWeights + blockStruct.num_files;
                    end
                end

                avgMat = sumMat ./ sumWeights;
                avgMat(isnan(avgMat)) = 0;

                newField = [blockName '_' condition];
                combinedStruct.(newField).epoch_avg = avgMat;
                combinedStruct.(newField).num_files = sumWeights;
            end
        end

        % Sort fields by block number and iteration
        allFields = fieldnames(combinedStruct);
        tokens = regexp(allFields, 'Block(\d+)_(\d+)_', 'tokens');
        sortKeys = zeros(length(tokens), 2);

        for i = 1:length(tokens)
            if ~isempty(tokens{i})
                sortKeys(i,1) = str2double(tokens{i}{1}{1});
                sortKeys(i,2) = str2double(tokens{i}{1}{2});
            end
        end

        [~, sortIdx] = sortrows(sortKeys);
        sortedFields = allFields(sortIdx);

        % Rebuild struct in sorted order
        sortedStruct = struct();
        for i = 1:length(sortedFields)
            sortedStruct.(sortedFields{i}) = combinedStruct.(sortedFields{i});
        end

        % Save sorted struct
        outputWrapper = struct();
        newTag = [erase(subjectTag, '_6B') '_6C2'];
        outputWrapper.(newTag) = sortedStruct;
        outputPath = fullfile(outputDir, [newTag '.mat']);
        save(outputPath, '-struct', 'outputWrapper', '-v7.3');
        disp(['Saved combined block file to: ', outputPath]);
    end
end
