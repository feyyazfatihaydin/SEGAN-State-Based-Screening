function scenarios = list_withholding_scenarios(economicRatios, physicalRatios, strategicGenerators)
%LIST_WITHHOLDING_SCENARIOS Generate the published sixteen-scenario design.
%   The scenario library contains CW0, three ECW, three FCW, and nine CCW
%   cases in a deterministic order. The strategic set can contain one or
%   multiple generator indices.

    economicRatios = economicRatios(:).';
    physicalRatios = physicalRatios(:).';
    strategicGenerators = strategicGenerators(:).';
    assert(numel(economicRatios) == 3 && numel(physicalRatios) == 3, ...
        'The published scenario library requires three ECW and three FCW levels.');
    assert(all(economicRatios > 0 & economicRatios < 1) && ...
           all(physicalRatios > 0 & physicalRatios < 1), ...
           'Withholding ratios must be between zero and one.');
    assert(~isempty(strategicGenerators) && ...
           all(strategicGenerators >= 1) && ...
           all(strategicGenerators == floor(strategicGenerators)), ...
           'Strategic generator indices must be positive integers.');

    scenarios = struct('ID', {}, 'Regime', {}, 'Name', {}, ...
                       'ECW', {}, 'FCW', {}, 'StrategicGenerators', {});
    scenarios(end+1) = make_scenario('CW0', 'CW0_BASE', 0, 0, strategicGenerators);
    for e = economicRatios
        scenarios(end+1) = make_scenario('ECW', sprintf('ECW_E%.2f', e), ...
                                         e, 0, strategicGenerators);
    end
    for f = physicalRatios
        scenarios(end+1) = make_scenario('FCW', sprintf('FCW_F%.2f', f), ...
                                         0, f, strategicGenerators);
    end
    for e = economicRatios
        for f = physicalRatios
            scenarios(end+1) = make_scenario('CCW', ...
                sprintf('CCW_E%.2f_F%.2f', e, f), e, f, strategicGenerators);
        end
    end
    for s = 1:numel(scenarios)
        scenarios(s).ID = s;
    end
    assert(numel(scenarios) == 16, 'Unexpected scenario count.');
end

function scenario = make_scenario(regime, name, economicRatio, physicalRatio, strategicGenerators)
    scenario = struct('ID', 0, 'Regime', regime, 'Name', name, ...
        'ECW', economicRatio, 'FCW', physicalRatio, ...
        'StrategicGenerators', strategicGenerators);
end
