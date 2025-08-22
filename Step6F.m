function Step6F(inputDir, outputDir)
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Get list of .mat files (each per subject)
    files = dir(fullfile(inputDir, '*.mat'));
    combinedStruct = struct();

    for f = 1:length(files)
        disp(['Processing subject: ', num2str(f), '/', num2str(length(files))]);
        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        subjName = fieldnames(data);
        subjStruct = data.(subjName{1});  % Expects format like All_Subjects_6D

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

                % Expand weight matrix across time
                expandedWeight = repmat(thisWeight, 1, size(thisData, 2));

                % Initialize condition if not present
                if ~isfield(combinedStruct, condition)
                    combinedStruct.(condition).epoch_sum = zeros(size(thisData));
                    combinedStruct.(condition).file_weight = zeros(size(thisWeight));
                end

                % Accumulate weighted data
                combinedStruct.(condition).epoch_sum = ...
                    combinedStruct.(condition).epoch_sum + thisData .* expandedWeight;
                combinedStruct.(condition).file_weight = ...
                    combinedStruct.(condition).file_weight + thisWeight;
            end
        end
    end

    % Final averaging per condition
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

    % Save output
    outputName = 'All_Subjects_6F';
    outputPath = fullfile(outputDir, [outputName '.mat']);
    tempStruct.(outputName) = finalStruct;
    save(outputPath, '-struct', 'tempStruct', '-v7.3');
    disp(['Saved combined struct to ', outputPath]);
end
