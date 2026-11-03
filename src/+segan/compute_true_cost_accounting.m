function econ = compute_true_cost_accounting(hourly, trueCost, generatorBus)
%COMPUTE_TRUE_COST_ACCOUNTING Evaluate settled dispatch using baseline costs.
%   ECON = SEGAN.COMPUTE_TRUE_COST_ACCOUNTING(HOURLY, TRUECOST, GENERATORBUS)
%   uses saved reported-offer OPF outcomes to compute ex-post economic
%   quantities. Reported offer coefficients must never enter these formulas.
%
%   The fixed cost is charged once per generator per day, not per hour.
%   Hourly profits follow the paper's hourly net-earning convention.
%
%   Inputs:
%     HOURLY.DispatchMW  : hours-by-generators, MW
%     HOURLY.LMP         : hours-by-buses, model $/MWh
%     TRUECOST.a         : linear baseline costs
%     TRUECOST.b         : quadratic baseline costs
%     TRUECOST.Fcost     : daily generator fixed costs
%     GENERATORBUS       : generator-to-bus indices
%
%   Output values are in model monetary units per hour or day.

    required = {'DispatchMW', 'LMP', 'Success'};
    assert(isstruct(hourly) && all(isfield(hourly, required)), ...
        'Hourly OPF results are missing required fields.');
    assert(isstruct(trueCost) && ...
        all(isfield(trueCost, {'a', 'b', 'Fcost'})), ...
        'Baseline cost inputs are missing.');

    dispatch = hourly.DispatchMW;
    nodalLMP = hourly.LMP;
    [nHours, nGen] = size(dispatch);
    busIndex = generatorBus(:).';

    assert(nHours == 24, 'The five-bus study requires a full 24-hour day.');
    assert(isequal(size(hourly.Success), [nHours, 1]) && ...
           all(hourly.Success), 'All 24 DC-OPF hours must have succeeded.');
    assert(numel(busIndex) == nGen && ...
           all(busIndex >= 1) && all(busIndex == fix(busIndex)) && ...
           all(busIndex <= size(nodalLMP, 2)), ...
        'Invalid generator-to-bus mapping.');

    trueA = trueCost.a(:).';
    trueB = trueCost.b(:).';
    fixedCost = trueCost.Fcost(:).';
    assert(numel(trueA) == nGen && numel(trueB) == nGen && ...
           numel(fixedCost) == nGen, 'Baseline cost dimensions do not match generators.');
    assert(all(isfinite([dispatch(:); nodalLMP(:); trueA(:); ...
        trueB(:); fixedCost(:)])), 'Economic accounting inputs must be finite.');

    % Settlement uses the solved nodal LMP at each generator's bus.
    generatorLMP = nodalLMP(:, busIndex);
    revenueHourly = generatorLMP .* dispatch;

    % Crucial methodological distinction: true costs, NOT reported offers.
    costVariableHourly = dispatch .* trueA + (dispatch.^2) .* trueB;
    netEarningHourly = revenueHourly - costVariableHourly;

    % The daily fixed cost is included exactly once per generator.
    revenueDaily = sum(revenueHourly, 1);
    costVariableDaily = sum(costVariableHourly, 1);
    costTotalDaily = costVariableDaily + fixedCost;
    netEarningDaily = sum(netEarningHourly, 1);
    profitDaily = netEarningDaily - fixedCost;

    econ = struct();
    econ.Hourly = struct( ...
        'GeneratorLMP', generatorLMP, ...
        'Revenue', revenueHourly, ...
        'TrueVariableCost', costVariableHourly, ...
        'NetEarning', netEarningHourly, ...
        'ProfitConvention', netEarningHourly);
    econ.Daily = struct( ...
        'Revenue', revenueDaily, ...
        'TrueVariableCost', costVariableDaily, ...
        'FixedCost', fixedCost, ...
        'TrueTotalCost', costTotalDaily, ...
        'NetEarning', netEarningDaily, ...
        'Profit', profitDaily);
    econ.SystemDaily = struct( ...
        'Revenue', sum(revenueDaily), ...
        'TrueVariableCost', sum(costVariableDaily), ...
        'TrueTotalCost', sum(costTotalDaily), ...
        'NetEarning', sum(netEarningDaily), ...
        'Profit', sum(profitDaily));
    econ.Method = 'Baseline cost accounting after reported-offer DC-OPF';

    % Check both independent daily accounting identities.
    accountingTolerance = 1e-8 * max(1, max(abs(revenueDaily)));
    assert(all(abs(netEarningDaily - (revenueDaily - costVariableDaily)) ...
           <= accountingTolerance), 'Daily net-earning identity failed.');
    assert(all(abs(profitDaily - (revenueDaily - costTotalDaily)) ...
           <= accountingTolerance), 'Daily profit identity failed.');
end
