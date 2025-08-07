function Step7BoxplotCompGFP(dirList, dirNames, outputDir)

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    Fs = 500;
    totalSamples = 1051;
    timeVec = linspace(-0.1, 2.1 - 0.1, totalSamples);
    startIndex = find(timeVec >= 0, 1, 'first');
    endIndex = find(timeVec <= 0.8, 1, 'last');

    allConditions = {};
    gfpRanges = struct();
    groupAnovaResults = {};  % Group-level across conditions
    condAnovaResults = {};   % Condition-level across groups

    % Loop through groups
    for g = 1:length(dirList)
        groupDir = dirList{g};
        files = dir(fullfile(groupDir, '*.mat'));
        if isempty(files)
            error(['No .mat files found in ', groupDir]);
        end

        condVals = {};
        condLabels = {};

        for f = 1:length(files)
            filePath = fullfile(groupDir, files(f).name);
            data = load(filePath);
            varName = fieldnames(data);
            subjStruct = data.(varName{1});
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames);

            for c = 1:length(condNames)
                cond = condNames{c};
                eeg = subjStruct.(cond).epoch_avg(:, startIndex:endIndex) * 1e6;
                GFP = std(eeg, 0, 1);
                rangeVal = max(abs(GFP)) - min(abs(GFP));

                condVals{end+1} = rangeVal;
                condLabels{end+1} = cond;

                if ~isfield(gfpRanges, cond)
                    gfpRanges.(cond) = cell(1, length(dirList));
                end
                gfpRanges.(cond){g}(end+1) = rangeVal;
            end
        end

        % Group-level ANOVA across conditions
        if length(unique(condLabels)) > 1
            [p, ~, ~] = anova1(cell2mat(condVals), condLabels, 'off');
            groupAnovaResults{end+1, 1} = dirNames{g};
            groupAnovaResults{end, 2} = p;
        end
    end

    % Condition-level ANOVAs across groups
    for i = 1:length(allConditions)
        cond = allConditions{i};
        vals = [];
        groupLabels = {};
        for g = 1:length(dirList)
            groupVals = gfpRanges.(cond){g};
            vals = [vals, groupVals];
            groupLabels = [groupLabels, repmat({dirNames{g}}, 1, length(groupVals))];
        end
        if length(unique(groupLabels)) > 1
            [p, ~, ~] = anova1(vals, groupLabels, 'off');
            condAnovaResults{end+1, 1} = cond;
            condAnovaResults{end, 2} = p;
        end
    end

    % Plotting boxplots with p-values for between-group comparisons
    condList = sort(allConditions);
    fig = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]);

    for i = 1:length(condList)
        cond = condList{i};
        subplot(2, 2, i);
        hold on;

        rangeVals = [];
        groupLabels = {};

        for g = 1:length(dirList)
            rVals = gfpRanges.(cond){g};
            rangeVals = [rangeVals, rVals];
            groupLabels = [groupLabels, repmat({dirNames{g}}, 1, length(rVals))];
        end

        boxplot(rangeVals, groupLabels, 'Widths', 0.6);
        title(cond);
        ylabel('GFP Range (Max - Min) µV');
        ylim([0, 3]);
        grid on;

        % Find and print ANOVA p-value for this condition
        condIdx = find(strcmp(condList{i}, condAnovaResults(:, 1)));
        if ~isempty(condIdx)
            pVal = condAnovaResults{condIdx, 2};
            text(0.5, -0.5, sprintf('p = %.4f', pVal), 'Units', 'normalized', ...
                'FontSize', 10, 'HorizontalAlignment', 'center');
        end
    end

    sgtitle('GFP Peak-to-Trough Range (0–0.8s) Across Groups', 'FontSize', 13);
    savePath = fullfile(outputDir, 'Boxplot_GFP_Range.png');
    exportgraphics(fig, savePath);
    close(fig);
    disp(['Saved figure to: ', savePath]);

    % Save ANOVA results across conditions per group
    condCSV = fullfile(outputDir, 'ConditionANOVAs_ByGroup.csv');
    fid = fopen(condCSV, 'w');
    fprintf(fid, 'GroupName,pValue\n');
    for i = 1:size(groupAnovaResults, 1)
        fprintf(fid, '%s,%.6f\n', groupAnovaResults{i, 1}, groupAnovaResults{i, 2});
    end
    fclose(fid);
    disp(['Saved group-wise condition ANOVA results to: ', condCSV]);

    % Save ANOVA results across groups per condition
    groupCSV = fullfile(outputDir, 'GroupANOVAs_ByCondition.csv');
    fid = fopen(groupCSV, 'w');
    fprintf(fid, 'Condition,pValue\n');
    for i = 1:size(condAnovaResults, 1)
        fprintf(fid, '%s,%.6f\n', condAnovaResults{i, 1}, condAnovaResults{i, 2});
    end
    fclose(fid);
    disp(['Saved condition-wise group ANOVA results to: ', groupCSV]);
end