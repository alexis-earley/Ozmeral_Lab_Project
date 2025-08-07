function Step6A(sourceFolder, destFolder)
    % Create destination folder if it doesn't exist
    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    % Process all .mat files in the source folder
    files = dir(fullfile(sourceFolder, '*.mat'));
    for j = 1:length(files)
        tempStruct = struct();  % Clear per file

        fileName = files(j).name;
        sourcePath = fullfile(sourceFolder, fileName);

        [~, nameOnly, ~] = fileparts(fileName);
        outputTag = [nameOnly '_6A']; % Add _6A to the struct name
        destinationPath = fullfile(destFolder, [outputTag '.mat']); % And to the output filename

        disp(['Processing file: ', fileName]);

        % Load the struct
        data = load(sourcePath);
        varName = fieldnames(data);
        topVarName = varName{1};
        structData = data.(topVarName);
        disp(['Loaded struct variable: ', topVarName]);

        % Main section
        modifiedCount = 0;
        subjNames = fieldnames(structData);

        for i = 1:length(subjNames)
            subj = subjNames{i};

            condNames = fieldnames(structData.(subj));
            for j2 = 1:length(condNames)
                cond = condNames{j2};

                trigNames = fieldnames(structData.(subj).(cond));
                for k = 1:length(trigNames)
                    trig = trigNames{k};

                    epochNames = fieldnames(structData.(subj).(cond).(trig));
                    for m = 1:length(epochNames)
                        epoch = epochNames{m};

                        matrix = structData.(subj).(cond).(trig).(epoch);

                        if isnumeric(matrix) && ismatrix(matrix)
                            nRows = size(matrix, 1);

                            if nRows == 63 % Ignore if it already was processed
                                continue;
                            elseif nRows == 70 || nRows == 88 % Remove unwanted channels
                                rowsToDelete = [32, 65:nRows];
                                rows = 1:nRows;
                                rows(rowsToDelete) = [];
                                structData.(subj).(cond).(trig).(epoch) = matrix(rows,:);
                                modifiedCount = modifiedCount + 1;
                            elseif nRows == 69
                                rowsToDelete = [64:nRows];
                                rows = 1:nRows;
                                rows(rowsToDelete) = [];
                                structData.(subj).(cond).(trig).(epoch) = matrix(rows,:);
                                modifiedCount = modifiedCount + 1;
                            else
                                error(['Matrix "', epoch, '" has ', num2str(nRows), ...
                                       ' rows (expected 63, 69, 70, or 88).']);
                            end
                        end
                    end
                end
            end
        end

        disp([num2str(modifiedCount), ' fields modified in file: ', fileName]);

        % Save updated struct with new _6A tag
        tempStruct.(outputTag) = structData;
        save(destinationPath, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPath]);
    end

    disp('All files processed and saved to new directory.');
end
