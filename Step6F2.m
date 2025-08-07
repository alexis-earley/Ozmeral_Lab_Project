function Step6F2(inputDir, outputDir)
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', inputDir);
    end

    for f = 1:length(files)
        disp(['Processing subject: ', num2str(f), '/', num2str(length(files))]);
        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        rootName = fieldnames(data);  % Ex: {'All_Subjects_6E'}
        subjStruct = data.(rootName{1});

        combinedStruct = struct();
        condNames = fieldnames(subjStruct);
        for i = 1:length(condNames)
            condition = condNames{i};
            trigNames = fieldnames(subjStruct.(condition));

            for j = 1:length(trigNames)
                trigger = trigNames{j};
                thisData = subjStruct.(condition).(trigger).epoch_avg;
                thisWeight = subjStruct.(condition).(trigger).num_files;

                if ~all(isfinite(thisData(:)))
                    error('Non-finite values found in data.');
                end

                expandedWeight = repmat(thisWeight, 1, size(thisData, 2));

                if ~isfield(combinedStruct, condition)
                    combinedStruct.(condition).epoch_sum = zeros(size(thisData));
                    combinedStruct.(condition).file_weight = zeros(size(thisWeight));
                end

                combinedStruct.(condition).epoch_sum = ...
                    combinedStruct.(condition).epoch_sum + thisData .* expandedWeight;
                combinedStruct.(condition).file_weight = ...
                    combinedStruct.(condition).file_weight + thisWeight;
            end
        end

        % Final averaging
        finalStruct = struct();
        condList = fieldnames(combinedStruct);
        for i = 1:length(condList)
            condition = condList{i};
            sumData = combinedStruct.(condition).epoch_sum;
            totalWeight = combinedStruct.(condition).file_weight;
            expandedWeight = repmat(totalWeight, 1, size(sumData, 2));
            avgData = sumData ./ expandedWeight;

            if ~all(isfinite(avgData(:)))
                error('Non-finite values in final average.');
            end

            finalStruct.(condition).epoch_avg = avgData;
            finalStruct.(condition).num_files = totalWeight;
        end

        % Save using updated struct name and clear any leftovers
        [~, baseName, ~] = fileparts(files(f).name);
        structOutName = [rootName{1}(1:end-2), '6F'];  % Ex: All_Subjects_6E → All_Subjects_6F
        outPath = fullfile(outputDir, [structOutName, '.mat']);
        tempStruct = struct();  % Clear previous content
        tempStruct.(structOutName) = finalStruct;
        save(outPath, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved final struct to ', outPath]);
    end
end