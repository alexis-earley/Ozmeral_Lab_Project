function RenameTriggerFields(inputDir, outputDir)
% Renames 'epoch_avg_trigger' → 'epoch_avg' and 'num_files_trigger' → 'num_files'
% in each .mat file inside inputDir, saving results to outputDir

    % Ensure output directory exists
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Get list of all .mat files in inputDir
    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    for i = 1:length(files)
        fileName = files(i).name;
        inputPath = fullfile(inputDir, fileName);
        outputPath = fullfile(outputDir, fileName);

        disp(['Processing file: ', fileName]);

        % Load the struct
        data = load(inputPath);
        topField = fieldnames(data);
        topName = topField{1};  % Ex: 'All_Subjects_6D'
        origStruct = data.(topName);

        % Prepare new struct
        newStruct = struct();

        condList = fieldnames(origStruct);
        for c = 1:length(condList)
            condName = condList{c};
            trigList = fieldnames(origStruct.(condName));

            for t = 1:length(trigList)
                trigName = trigList{t};
                trigData = origStruct.(condName).(trigName);

                % Rename fields
                updatedTrig.epoch_avg = trigData.epoch_avg_trigger;
                updatedTrig.num_files = trigData.num_files_trigger;

                % Save updated trigger
                newStruct.(condName).(trigName) = updatedTrig;
            end
        end

        % Wrap and save updated struct
        outputStruct.(topName) = newStruct;
        save(outputPath, '-struct', 'outputStruct', '-v7.3');
        disp(['Saved renamed file to: ', outputPath]);
    end

    disp('All files processed and saved.');
end
