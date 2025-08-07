function Step7GraphCompareGroupsFixedMaybe(dirList, dirNames, outputDir)
% Compares GFPs across groups by averaging EEG data per subject,
% then computing GFP from the group-average EEG.
%
% dirList = {'./Group1', './Group2'};
% dirNames = {'ONH', 'OHI'};
% outputDir = './Group_Comparison';

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    Fs = 500;  % Sampling frequency
    cutoff = 30;
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    allEEG = struct();   % Stores EEG: allEEG.(cond){group} = [subjects x channels x time]
    allConditions = {};

    for g = 1:length(dirList)
        groupDir = dirList{g};
        files = dir(fullfile(groupDir, '*.mat'));
        if isempty(files)
            error(['No .mat files found in ', groupDir]);
        end

        for f = 1:length(files)
            filePath = fullfile(groupDir, files(f).name);
            S = load(filePath);
            structName = fieldnames(S);
            subjStruct = S.(structName{1});
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames);

            for c = 1:length(condNames)
                cond = condNames{c};
                data = subjStruct.(cond).epoch_avg * 1e6;  % µV

                for ch = 1:size(data, 1)
                    if all(isfinite(data(ch, :)))
                        data(ch, :) = filtfilt(b, a, data(ch, :));
                    end
                end

                if ~isfield(allEEG, cond)
                    allEEG.(cond) = cell(1, length(dirList));
                end

                % Store EEG as 1 subject in group
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
    ts = linspace(-0.1, 2, size(data, 2));

    for i = 1:length(condList)
        cond = condList{i};
        subplot(2, 2, i);
        hold on;

        for g = 1:length(dirList)
            if isempty(allEEG.(cond){g})
                continue;
            end

            groupEEG = squeeze(mean(allEEG.(cond){g}, 1));  % avg over subjects → channels x time
            GFP = std(groupEEG, 0, 1);

            plot(ts, GFP, 'LineWidth', 2);
        end

        title(cond);
        xlabel('Time (s)');
        ylabel('GFP (µV)');
        xlim([-0.1, 2]);
        ylim([-2, 2]);
        grid on;
        legend(dirNames, 'Location', 'northeast');
    end

    sgtitle('Condition-wise Group-Averaged GFP Comparison', 'FontSize', 12);
    savePath = fullfile(outputDir, 'GroupComparison_GFP.png');
    exportgraphics(fig, savePath);
    close(fig);
    disp(['Saved figure to: ', savePath]);
end