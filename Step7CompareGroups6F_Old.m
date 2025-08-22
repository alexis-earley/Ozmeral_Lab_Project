function Step7CompareGroups6F_Old(dirList, dirNames, outputDir, maxTime)

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if nargin < 4 || ~isscalar(maxTime) || maxTime <= 0 || maxTime > 2
        error('maxTime must be a scalar between 0 and 2 seconds.');
    end

    Fs = 500;  % Hz
    totalSamples = 1051;
    totalDuration = 2.1;
    timeVec = linspace(-0.1, totalDuration - 0.1, totalSamples);
    lastIndex = find(timeVec <= maxTime, 1, 'last');
    ts = timeVec(1:lastIndex);

    cutoff = 30;
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    allData = struct();
    allConditions = {};

    for g = 1:length(dirList)
        groupDir = dirList{g};
        files = dir(fullfile(groupDir, '*.mat'));
        if isempty(files)
            error(['No .mat files found in ', groupDir]);
        end

        for f = 1:length(files)
            filePath = fullfile(groupDir, files(f).name);
            data = load(filePath);
            varName = fieldnames(data);
            subjStruct = data.(varName{1});
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames);

            for c = 1:length(condNames)
                cond = condNames{c};
                rawData = subjStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6;

                for ch = 1:size(rawData, 1)
                    if all(isfinite(rawData(ch, :)))
                        rawData(ch, :) = filtfilt(b, a, rawData(ch, :));
                    end
                end

                GFP = std(rawData);  % 1 x time

                if ~isfield(allData, cond)
                    allData.(cond) = cell(1, length(dirList));
                end
                if isempty(allData.(cond){g})
                    allData.(cond){g} = GFP;
                else
                    allData.(cond){g}(end+1, :) = GFP;
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
            gData = allData.(cond){g};
            if isempty(gData)
                continue;
            end

            avgGFP = mean(gData, 1);
            seGFP = std(gData, 0, 1) / sqrt(size(gData, 1));
            upper = avgGFP + seGFP;
            lower = avgGFP - seGFP;

            % Shaded SE area (invisible to legend)
            hFill = fill([ts fliplr(ts)], [upper fliplr(lower)], ...
                'k', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
            hFill.Annotation.LegendInformation.IconDisplayStyle = 'off';

            % Main line with DisplayName
            plot(ts, avgGFP, 'LineWidth', 2, 'DisplayName', dirNames{g});
        end

        title(cond);
        xlabel('Time (s)');
        ylabel('GFP (µV)');
        xlim([-0.1, maxTime]);
        ylim([-2, 2]);
        grid on;
        legend('Location', 'northeast');
    end

    sgtitle('Condition-wise GFP with SE Shading Across Groups', 'FontSize', 12);
    savePath = fullfile(outputDir, 'GroupComparison_AllConditions.png');
    exportgraphics(fig, savePath);
    close(fig);
    disp(['Saved figure to: ', savePath]);
end