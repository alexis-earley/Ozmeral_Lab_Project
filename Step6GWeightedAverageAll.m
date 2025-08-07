function Step6GWeightedAverageAll(inputDir, outputDir)
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Gather all .mat files
    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', inputDir);
    end

    combinedStruct = struct();

    % Loop through each subject file
    for f = 1:length(files)
        disp(['Including subject: ', num2str(f), '/', num2str(length(files))]);
        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        rootName = fieldnames(data);
        subjStruct = data.(rootName{1});  % Expects Step6F format: condition → epoch_avg + num_files

        condNames = fieldnames(subjStruct);
        for i = 1:numel(condNames)
            cond = condNames{i};
            thisData = subjStruct.(cond).epoch_avg;
            thisWeight = subjStruct.(cond).num_files;

            if ~all(isfinite(thisData(:)))
                error('Non-finite values found in subject: %s, condition: %s', files(f).name, cond);
            end

            if ~isfield(combinedStruct, cond)
                combinedStruct.(cond).epoch_sum = zeros(size(thisData));
                combinedStruct.(cond).file_weight = zeros(size(thisWeight));
            end

            expandedWeight = repmat(thisWeight, 1, size(thisData, 2));
            combinedStruct.(cond).epoch_sum = combinedStruct.(cond).epoch_sum + thisData .* expandedWeight;
            combinedStruct.(cond).file_weight = combinedStruct.(cond).file_weight + thisWeight;
        end
    end

    % Compute final weighted average
    finalStruct = struct();
    condList = fieldnames(combinedStruct);
    for i = 1:numel(condList)
        cond = condList{i};
        sumData = combinedStruct.(cond).epoch_sum;
        totalWeight = combinedStruct.(cond).file_weight;
        expandedWeight = repmat(totalWeight, 1, size(sumData, 2));
        avgData = sumData ./ expandedWeight;

        if ~all(isfinite(avgData(:)))
            error('Non-finite values in final average for condition: %s', cond);
        end

        finalStruct.(cond).epoch_avg = avgData;
        finalStruct.(cond).num_files = totalWeight;
    end

    % Save result
    outputFile = fullfile(outputDir, 'All_Subjects_6G.mat');
    All_Subjects_6G = finalStruct;  % wrap in top-level struct
    save(outputFile, 'All_Subjects_6G', '-v7.3');
    disp(['Saved final group average to: ', outputFile]);
end