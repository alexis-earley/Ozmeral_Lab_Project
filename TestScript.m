%function RepackStructs(inputFolder, outputFolder)
    % RepackStructs
    % Combines all top-level variables in each .mat file into a single struct
    % with the same name as the file, and saves it in outputFolder.
    %
    % Example:
    %   RepackStructs('E:\Input', 'E:\Output')

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    files = dir(fullfile(inputFolder, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', inputFolder);
    end

    for f = 1:length(files)
        inPath = fullfile(inputFolder, files(f).name);
        [~, baseName, ~] = fileparts(files(f).name);

        disp(['Processing: ' baseName]);

        % Load the file (it may have multiple top-level variables)
        fileData = load(inPath);

        % Merge all top-level variables into one struct
        combinedStruct = struct();
        varNames = fieldnames(fileData);

        for v = 1:length(varNames)
            combinedStruct.(varNames{v}) = fileData.(varNames{v});
        end

        % Wrap under filename-based struct
        outStruct = struct();
        outStruct.(baseName) = combinedStruct;

        % Save to output folder
        outPath = fullfile(outputFolder, files(f).name);
        save(outPath, '-struct', 'outStruct', '-v7.3');

        disp(['Saved repacked file to: ' outPath]);
    end

    disp('All files repacked successfully.');
%end