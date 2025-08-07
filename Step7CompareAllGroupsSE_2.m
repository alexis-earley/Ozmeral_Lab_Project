function Step7CompareAllGroupsSE_2(dirList, dirNames, outputDir, maxTime)

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if nargin < 4 || ~isscalar(maxTime) || maxTime <= 0 || maxTime > 2
        error('maxTime must be a scalar between 0 and 2 seconds.');
    end

    Fs = 500;  % Sampling rate
    totalSamples = 1051;
    totalDuration = 2.1;
    timeVec = linspace(-0.1, totalDuration - 0.1, totalSamples);
    lastIndex = find(timeVec <= maxTime, 1, 'last');
    ts = timeVec(1:lastIndex);

    cutoff = 30;
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    allEEG = struct();   % allEEG.(cond){g} = [subjects x channels x time]
    allConditions = {};

    for g = 1:length(dirList)
        groupDir = dirList{g};
        files = dir(fullfile(groupDir, '*.mat'));
        if isempty(files)
            error(['No .mat files found in ', groupDir]);
        end

        for f = 1:length(files)
            S = load(fullfile(groupDir, files(f).name));
            varName = fieldnames(S);
            subjStruct = S.(varName{1});
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames);

            for c = 1:length(condNames)
                cond = condNames{c};
                data = subjStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6;

                for ch = 1:size(data, 1)
                    if all(isfinite(data(ch, :)))
                        data(ch, :) = filtfilt(b, a, data(ch, :));
                    end
                end

                if ~isfield(allEEG, cond)
                    allEEG.(cond) = cell(1, length(dirList));
                end

                if isempty(allEEG.(cond){g})
                    allEEG.(cond){g} = reshape(data, 1, size(data, 1), size(data, 2));
                else
                    allEEG.(cond){g}(end+1, :, :) = data;
                end
            end
        end
    end

    % Plotting
    condList = sort(allConditions);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]);

    for i = 1:length(condList)
        cond = condList{i};
        subplot(2, 2, i);
        hold on;

        for g = 1:length(dirList)
            EEG = allEEG.(cond){g};
            if isempty(EEG)
                continue;
            end

            subjGFPs = squeeze(std(EEG, 0, 2));  % subjects x time
            GFP = mean(subjGFPs, 1);             % mean(std()) across subjects
            seGFP = std(subjGFPs, 0, 1) / sqrt(size(EEG, 1));  % standard error

            upper = GFP + seGFP;
            lower = GFP - seGFP;

            fill([ts fliplr(ts)], [upper fliplr(lower)], ...
                'k', 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');

            plot(ts, GFP, 'LineWidth', 2, 'DisplayName', dirNames{g});
        end

        title(cond);
        xlabel('Time (s)');
        ylabel('GFP (µV)');
        xlim([-0.1, maxTime]);
        ylim([-2, 2]);
        grid on;
        legend('Location', 'northeast');
    end

    sgtitle('Condition-wise GFP with SE Shading Across Groups (mean(std))', 'FontSize', 12);
    savePath = fullfile(outputDir, 'GroupComparison_AllConditions_meanSTD.png');
    exportgraphics(fig, savePath);
    close(fig);
    disp(['Saved figure to: ', savePath]);
end