function Step7GraphAll6G(inputDir, outputDir, subplotTitle, maxTime)
% Example usage:
%   Step7GraphAll6G(inputDir, outputDir, 'Older Normal Hearing', 0.8);

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if nargin < 4 || ~isscalar(maxTime) || maxTime <= 0 || maxTime > 2
        error('maxTime must be a scalar between 0 and 2 seconds.');
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', inputDir);
    end

    Fs = 500;  % Sampling frequency (Hz)
    cutoff = 30;  % Low-pass filter cutoff (Hz)
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    totalSamples = 1051;
    totalDuration = 2.1; % 1051 samples at 500 Hz
    timeVec = linspace(-0.1, totalDuration - 0.1, totalSamples);
    lastIndex = find(timeVec <= maxTime, 1, 'last');
    ts = timeVec(1:lastIndex);

    for f = 1:length(files)
        filePath = fullfile(inputDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        S = load(filePath);
        structName = fieldnames(S);
        dataStruct = S.(structName{1});  % Should be All_Subjects_6G

        condList = sort(fieldnames(dataStruct));
        numConds = length(condList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);

        fig = figure('Visible', 'off', 'Name', files(f).name, 'NumberTitle', 'off', ...
                     'Position', [100, 100, 1400, 900]);

        for i = 1:numConds
            cond = condList{i};
            data = dataStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6;  % µV

            for ch = 1:size(data, 1)
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                end
            end

            GFP = std(data);

            subplot(subplotRows, subplotCols, i);
            hold on;
            plot(ts, data, 'b', 'LineWidth', 0.5);
            plot(ts, GFP, 'r', 'LineWidth', 2);
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(cond);
            grid on;
            xlim([-0.1, maxTime]);
            ylim([-2, 2]);
        end

        if numConds > 1
            sgtitle([subplotTitle, ' Average Potentials - ', files(f).name], ...
                    'Interpreter', 'none', 'FontSize', 10);
        end

        [~, baseName, ~] = fileparts(files(f).name);
        savePath = fullfile(outputDir, [baseName, '_AllConditions.png']);
        suffix = 1;
        while isfile(savePath)
            savePath = fullfile(outputDir, [baseName, '_AllConditions_', num2str(suffix), '.png']);
            suffix = suffix + 1;
        end
        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved figure to: ', savePath]);
    end

    disp('All Step6G figures processed.');
end