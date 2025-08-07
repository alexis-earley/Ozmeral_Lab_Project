function Step6DNew2(inputDir, outputDir)
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Get list of input .mat files (each per subject)
    files = dir(fullfile(inputDir, '*.mat'));
    combinedStruct = struct();

    % Loop over subject files
    for f = 1:length(files)
        disp(['Incorporating subject: ', num2str(f), '/', num2str(length(files))]);
        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        subjName = fieldnames(data);
        subjStruct = data.(subjName{1});  % Get subject data (already weighted per trigger)

        condNames = fieldnames(subjStruct);
        for i = 1:length(condNames)
            condition = condNames{i};
            trigNames = fieldnames(subjStruct.(condition));

            for j = 1:length(trigNames)
                trigger = trigNames{j};
                thisData = subjStruct.(condition).(trigger).epoch_avg;  % 63 x 1051 
                % thisData  = thisData(:, 1:451); % COMMENTED OUT - WARNING - MAY BE IN PREVIOUS VERSIONS
                thisWeight = subjStruct.(condition).(trigger).num_files; % 63 x 1

                if ~all(isfinite(thisData(:)))
                    error('Non-finite values found in channel.');
                end

                % Expand weight matrix across columns
                expandedWeight = repmat(thisWeight, 1, size(thisData, 2));

                % Initialize if not present
                if ~isfield(combinedStruct, condition)
                    combinedStruct.(condition) = struct();
                end
                if ~isfield(combinedStruct.(condition), trigger)
                    combinedStruct.(condition).(trigger).epoch_sum = zeros(size(thisData));
                    combinedStruct.(condition).(trigger).file_weight = zeros(size(thisWeight));
                end

                % Weighted summation (element-wise)
                combinedStruct.(condition).(trigger).epoch_sum = ...
                    combinedStruct.(condition).(trigger).epoch_sum + thisData .* expandedWeight;
                combinedStruct.(condition).(trigger).file_weight = ...
                    combinedStruct.(condition).(trigger).file_weight + thisWeight;
            end
        end
    end

    % Final averaging
    finalStruct = struct();
    condList = fieldnames(combinedStruct);
    for i = 1:length(condList)
        condition = condList{i};
        finalStruct.(condition) = struct();

        trigList = fieldnames(combinedStruct.(condition));
        for j = 1:length(trigList)
            trigger = trigList{j};
            totalSum = combinedStruct.(condition).(trigger).epoch_sum;
            totalWeight = combinedStruct.(condition).(trigger).file_weight;

            % Expand weights across time dimension
            expandedWeight = repmat(totalWeight, 1, size(totalSum, 2));

            % Element-wise division
            finalAvg = totalSum ./ expandedWeight;
            if ~all(isfinite(finalAvg(:)))
                error('Non-finite values found in channel.');
            end

            % Save final fields
            finalStruct.(condition).(trigger).epoch_avg = finalAvg;
            finalStruct.(condition).(trigger).num_files = totalWeight;
        end
    end

    % Save with matching struct name
    outputFileName = 'All_Subjects_6D';
    outputPath = fullfile(outputDir, [outputFileName '.mat']);
    tempStruct.(outputFileName) = finalStruct;
    save(outputPath, '-struct', 'tempStruct', '-v7.3');
    disp(['Saved final combined struct to ', outputPath]);
end