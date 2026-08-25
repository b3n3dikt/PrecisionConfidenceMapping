function cDC = continuous_Dice_coefficient(A_binary, B_probability_map)
    AB = A_binary .* B_probability_map;
    c = sum(AB(:)) / max(nnz(AB), 1);
    cDC = 2 * sum(AB(:)) / (c * sum(A_binary(:)) + sum(B_probability_map(:)));
end
