function TestScript(inputDir, outputDir)

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

        subjStruct = data.(rootName{1});  % Expects Step6F format: condition → epoch_avg

        condNames = fieldnames(subjStruct);

        for i = 1:numel(condNames)

            cond = condNames{i};

            thisData = subjStruct.(cond).epoch_avg;

            if ~all(isfinite(thisData(:)))

                error('Non-finite values found in subject: %s, condition: %s', files(f).name, cond);

            end

            % Initialize accumulators

            if ~isfield(combinedStruct, cond)

                combinedStruct.(cond).epoch_sum = zeros(size(thisData));

                combinedStruct.(cond).num_subjects = 0;

            end

            % Add subject data (no weights)

            combinedStruct.(cond).epoch_sum = combinedStruct.(cond).epoch_sum + thisData;

            combinedStruct.(cond).num_subjects = combinedStruct.(cond).num_subjects + 1;

        end

    end

    % Compute final unweighted average

    finalStruct = struct();

    condList = fieldnames(combinedStruct);

    for i = 1:numel(condList)

        cond = condList{i};

        sumData = combinedStruct.(cond).epoch_sum;

        nSubjects = combinedStruct.(cond).num_subjects;

        avgData = sumData ./ nSubjects;

        if ~all(isfinite(avgData(:)))

            error('Non-finite values in final average for condition: %s', cond);

        end

        finalStruct.(cond).epoch_avg = avgData;

        finalStruct.(cond).num_subjects = nSubjects;

    end

    % Save result

    outputFile = fullfile(outputDir, 'All_Subjects_6G_StrictAvg.mat');

    All_Subjects_6G = finalStruct;  % wrap in top-level struct

    save(outputFile, 'All_Subjects_6G', '-v7.3');

    disp(['Saved final group average to: ', outputFile]);

end
 