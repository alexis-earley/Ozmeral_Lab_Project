function Step7GraphAllFinal(sourceDir, destFolder, subplotTitle)
% Example:
%   Step7GraphAllFinal(sourceDir, destFolder, 'Older Hearing Impaired (Unaided)');
% Assumes source .mat file contains struct: all_subjects.(condition).epoch_avg

    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    files = dir(fullfile(sourceDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in source directory.');
    end

    % Define 30 Hz low-pass filter
    Fs = 500;  % Sampling rate
    cutoff = 30;  
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    for f = 1:length(files)
        filePath = fullfile(sourceDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        % Load the all_subjects struct
        fileStruct = load(filePath);
        topVar = fieldnames(fileStruct);
        weightedStruct = fileStruct.(topVar{1});

        % Set up subplot layout
        conditionList = sort(fieldnames(weightedStruct));
        numConds = length(conditionList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);
        fig = figure('Visible', 'off', 'Name', files(f).name, 'NumberTitle', 'off');

        % Plot each condition
        for i = 1:numConds
            condition = conditionList{i};
            data = weightedStruct.(condition).epoch_avg * 1e6;  % µV

            % Filter each channel
            for ch = 1:size(data, 1)
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                end
            end

            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, i);
            hold on;
            ts = linspace(-0.1, 2.0, size(data, 2));  
            plot(ts, data, 'b', 'LineWidth', 0.1);  
            plot(ts, GFP, 'r', 'LineWidth', 0.8);  
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(condition);
            grid on;
            xlim([-0.1, 2]);
            ylim([-4, 4]);
        end

        if numConds > 1
            sgtitle([subplotTitle, ' Average Potentials - ', files(f).name], ...
                    'Interpreter', 'none', 'FontSize', 10);
        end

        [~, baseName, ~] = fileparts(files(f).name);
        savePath = fullfile(destFolder, [baseName, '_AllConditions.png']);
        suffix = 1;
        while isfile(savePath)
            savePath = fullfile(destFolder, ...
                [baseName, '_AllConditions_', num2str(suffix), '.png']);
            suffix = suffix + 1;
        end

        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved figure to: ', savePath]);
    end

    disp('All figures processed.');
end