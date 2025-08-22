function Step6AAPeakDiffs_AllSubjects(inputDir, outputDir)
    % Step6AAPeakDiffs_AllSubjects
    % 1. For each subject, compute peak-to-peak values for each channel of each epoch
    % 2. Store all subjects in a struct: All_Subjects_6AA.(SubjectName) = 63 x n matrix
    % 3. Store all subjects combined into a single matrix: Combined_Channels_6AA

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', inputDir);
    end

    Combined_Channels_6AA = []; % Combined across all subjects
    All_Subjects_6AA = struct(); % Struct for per-subject storage

    for f = 1:length(files)
        disp(['Processing file ', num2str(f), '/', num2str(length(files)), ': ', files(f).name]);

        % Load subject struct
        data = load(fullfile(inputDir, files(f).name));
        fn = fieldnames(data);
        subjStruct = data.(fn{1});

        condNames = fieldnames(subjStruct);
        peakValsAll = []; % Per subject

        % Loop over conditions
        for c = 1:length(condNames)
            trigNames = fieldnames(subjStruct.(condNames{c}));

            % Loop over triggers
            for t = 1:length(trigNames)
                blockNames = fieldnames(subjStruct.(condNames{c}).(trigNames{t}));

                % Loop over blocks
                for b = 1:length(blockNames)
                    epochNames = fieldnames(subjStruct.(condNames{c}).(trigNames{t}).(blockNames{b}));

                    % Loop over epochs
                    for e = 1:length(epochNames)
                        epochData = subjStruct.(condNames{c}).(trigNames{t}).(blockNames{b}).(epochNames{e});

                        if ~(isnumeric(epochData) && ismatrix(epochData))
                            error('Epoch "%s" is not a numeric 2D matrix.', epochNames{e});
                        end

                        % Reduce to 63 channels
                        nRows = size(epochData, 1);
                        if nRows == 63
                            reducedData = epochData;
                        elseif nRows == 70 || nRows == 88
                            rowsToDelete = [32, 65:nRows];
                            reducedData = epochData(setdiff(1:nRows, rowsToDelete), :);
                        elseif nRows == 69
                            rowsToDelete = 64:nRows;
                            reducedData = epochData(setdiff(1:nRows, rowsToDelete), :);
                        else
                            error('Epoch "%s" has unexpected row count: %d', epochNames{e}, nRows);
                        end

                        % Compute peak-to-peak per channel
                        p2pVals = max(reducedData, [], 2) - min(reducedData, [], 2);

                        % Append to per-subject and global lists
                        peakValsAll = [peakValsAll, p2pVals];
                        Combined_Channels_6AA = [Combined_Channels_6AA, p2pVals];
                    end
                end
            end
        end

        % Store in struct with subject name as field
        [~, baseName, ~] = fileparts(files(f).name);
        All_Subjects_6AA.(baseName) = peakValsAll;

        disp(['Stored subject: ', baseName, ' (', num2str(size(peakValsAll,2)), ' epochs)']);
    end

    % Save struct
    save(fullfile(outputDir, 'All_Subjects_6AA.mat'), 'All_Subjects_6AA', '-v7.3');
    disp(['Saved All_Subjects_6AA struct to: ', fullfile(outputDir, 'All_Subjects_6AA.mat')]);

    % Save combined matrix
    save(fullfile(outputDir, 'Combined_Channels_6AA.mat'), 'Combined_Channels_6AA', '-v7.3');
    disp(['Saved Combined_Channels_6AA matrix to: ', fullfile(outputDir, 'Combined_Channels_6AA.mat')]);

    disp('All subjects processed for peak-to-peak values.');
end