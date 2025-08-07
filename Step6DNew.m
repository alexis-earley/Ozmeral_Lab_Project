function Step6DNew(inputDir, outputDir)
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Get list of input .mat files (each per subject)
    files = dir(fullfile(inputDir, '*.mat'));
    combinedStruct = struct();

    % Loop over subject files
    for f = 1:length(files)
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
                thisData = subjStruct.(condition).(trigger).epoch_avg_trigger;
                thisCount = subjStruct.(condition).(trigger).num_files_trigger;

                % Initialize if not present
                if ~isfield(combinedStruct, condition)
                    combinedStruct.(condition) = struct();
                end
                if ~isfield(combinedStruct.(condition), trigger)
                    combinedStruct.(condition).(trigger).epoch_sum = zeros(size(thisData));
                    combinedStruct.(condition).(trigger).file_count = 0;
                end

                % Weighted summation
                combinedStruct.(condition).(trigger).epoch_sum = ...
                    combinedStruct.(condition).(trigger).epoch_sum + thisData * thisCount;
                combinedStruct.(condition).(trigger).file_count = ...
                    combinedStruct.(condition).(trigger).file_count + thisCount;
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
            totalCount = combinedStruct.(condition).(trigger).file_count;

            finalStruct.(condition).(trigger).epoch_avg_trigger = totalSum / totalCount;
            finalStruct.(condition).(trigger).num_files_trigger = totalCount;
        end
    end

    % Save with matching struct name
    outputFileName = 'All_Subjects_6D';
    outputPath = fullfile(outputDir, [outputFileName '.mat']);
    tempStruct.(outputFileName) = finalStruct;
    save(outputPath, '-struct', 'tempStruct', '-v7.3');
    disp(['Saved final combined struct to ', outputPath]);
end
