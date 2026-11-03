function [mpc, reported] = apply_withholding(baseCase, trueCost, scenario, hourIndex, peakHours)
%APPLY_WITHHOLDING Apply exogenous reported offers at designated peak hours.
%   True/baseline cost coefficients are never changed in TRUECOST.
%   This function modifies only the reported offer and capacity used by OPF.

    define_constants;

    mpc = baseCase;
    a = trueCost.a(:);
    b = trueCost.b(:);
    pmax = baseCase.gen(:, PMAX);
    pmin = baseCase.gen(:, PMIN);
    strategicSet = scenario.StrategicGenerators(:);
    assert(all(strategicSet <= size(baseCase.gen, 1)), ...
        'The strategic generator index is outside the case.');
    active = ismember(hourIndex, peakHours);

    if active
        a(strategicSet) = a(strategicSet) .* (1 + scenario.ECW);
        b(strategicSet) = b(strategicSet) .* (1 + scenario.ECW);
        pmax(strategicSet) = max( ...
            pmax(strategicSet) .* (1 - scenario.FCW), pmin(strategicSet));
    end

    mpc.gen(:, PMAX) = pmax;
    mpc.gencost(:, 5) = b;
    mpc.gencost(:, 6) = a;
    mpc.gencost(:, 7) = 0;

    reported = struct('ActivePeakHour', active, ...
                      'a', a, 'b', b, 'Pmax', pmax);
end
