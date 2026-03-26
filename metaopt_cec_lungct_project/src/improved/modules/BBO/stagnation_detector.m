function no_improve_count = stagnation_detector(improved_this_iter, no_improve_count)
% stagnation_detector
% Update stagnation counter using a single reusable rule.

    if improved_this_iter
        no_improve_count = 0;
    else
        no_improve_count = no_improve_count + 1;
    end
end
