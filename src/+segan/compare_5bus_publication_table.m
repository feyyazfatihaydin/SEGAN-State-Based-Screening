function validation = compare_5bus_publication_table(stateSignature)
%COMPARE_5BUS_PUBLICATION_TABLE Compare new results with published Table 5.
%   Published rounded values are used ONLY for validation; never for model
%   features, clustering, labels, or economic-accounting calculations.
%
%   Tolerances reflect the displayed precision of the published quantities.

    required = {'Share','MeanLMP','LMPSpread', ...
        'MeanMaxLoading','FocusNetEarningTarget'};
    assert(istable(stateSignature) && height(stateSignature)==2 && ...
        all(ismember(required,stateSignature.Properties.VariableNames)), ...
        'Expected two named states and complete Table 5 signatures.');

    metrics = { ...
        'Share';'MeanLMP';'LMPSpread';'MeanMaxLoading'; ...
        'FocusNetEarningTarget'};
    published = [ ...
        0.417,0.583; ...
        23.135,26.953; ...
        18.533,27.708; ...
        100.00,100.00; ...
        712.6,3775.9];
    tolerances = [0.00051;0.00051;0.00051;0.0051;0.051];
    observed = nan(numel(metrics),2);
    for j=1:numel(metrics)
        observed(j,:) = stateSignature{:,metrics{j}}.';
    end
    delta = observed-published;
    pass = abs(delta) <= repmat(tolerances,1,2);

    n = numel(metrics)*2;
    state = strings(n,1);
    metric = strings(n,1);
    reference = zeros(n,1);
    measured = zeros(n,1);
    errorValue = zeros(n,1);
    tolerance = zeros(n,1);
    isMatch = false(n,1);
    row = 0;
    for k=1:2
        for j=1:numel(metrics)
            row = row+1;
            state(row) = stateSignature.State(k);
            metric(row) = string(metrics{j});
            reference(row) = published(j,k);
            measured(row) = observed(j,k);
            errorValue(row) = delta(j,k);
            tolerance(row) = tolerances(j);
            isMatch(row) = pass(j,k);
        end
    end
    validation = struct();
    validation.Details = table(state,metric,reference,measured, ...
        errorValue,tolerance,isMatch, ...
        'VariableNames',{'State','Metric','Published','Computed', ...
        'Difference','Tolerance','Pass'});
    validation.AllPass = all(isMatch);
    validation.PassedChecks = nnz(isMatch);
    validation.TotalChecks = numel(isMatch);
end
