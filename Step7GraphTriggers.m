function Step7GraphTriggers(inputDir, outputDir, subplotTitle)
% Example: Step7GraphTriggers('E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\ONH_Data_Structs\Step_6C_Output_New\Unaided','C:\Users\aearley1\Desktop\Brainstorm\Main_Location\MATLAB Figures\Step7_GraphTriggers_Output\ONH\Unaided','Older Normal Hearing')

    if ~exist(outputDir, 'dir')
        mkdir(outputDir); % Make main output folder
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get subject files
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    for i = 1:length(files)
        filePath = fullfile(inputDir, files(i).name);
        disp(['Processing: ', files(i).name]);

        % Load subject struct
        fileStruct = load(filePath);
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1}); % ex. Subject_0604_6C

        % Get subject number from name to label folder
        underscoreParts = split(varNames{1}, '_');
        subjNum = underscoreParts{2};

        subjFolder = fullfile(outputDir, subjNum);
        if ~exist(subjFolder, 'dir')
            mkdir(subjFolder);
        end

        condList = fieldnames(weightedStruct);
        ts = linspace(-0.1, 2.0, 1051);  % Time in seconds
        numConds = length(condList);

        for j = 1:numConds
            condition = condList{j};
            condStruct = weightedStruct.(condition);
            trigList = fieldnames(condStruct);

            fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [100, 100, 2000, 1200]);
            % Makes large figure so labels and such are visible

            for k = 1:length(trigList)
                trigName = trigList{k};
                dataStruct = condStruct.(trigName);
                data = dataStruct.epoch_avg_trigger * 1e6; % Convert to µV
                GFP = std(data);
                maxNum = max(abs(data(:)));

                subplot(5, 5, k);
                hold on;
                plot(ts, data, 'b', 'LineWidth', 0.1); % Channel data
                plot(ts, GFP, 'r', 'LineWidth', 2);    % GFP
                xlabel('Time (s)');
                ylabel('Amplitude (µV)');
                grid on;
                xlim([-0.1, 2.0]);

                % Y-limits and title warnings
                if maxNum <= 25
                    ylim([-25, 25]);
                    warningName = '';
                else
                    warningName = ' - WARNING';
                end

                safeTrigName = strrep(trigName, '_', '\_'); % Fixes it so MATLAB doesn't put subscripts for underscores
                titleStr = [safeTrigName, ' - ', num2str(dataStruct.num_files_trigger), ' files', warningName];
                titleProperties = title(titleStr);
                if maxNum > 25
                    titleProperties.Color = 'red';
                end
            end

            % Overall title
            sgtitle([subplotTitle, ' - Subject ', subjNum, ' - ', condition]);

            savePath = fullfile(subjFolder, [condition, '_Triggers.png']);
            exportgraphics(fig, savePath, 'Resolution', 300);
            close(fig);
        end
    end

    disp('All figures saved.');
end