{$H+}
{$CODEPAGE UTF-8}
program main;
uses list_unit, file_unit;
type
    pair_t = record
                first: dword;
                second: dword
            end;
var
{параметры конфигурации}
    output_file: text;
{взято из config.txt}
    mode, cmd_print: byte;
    variability, quality_epsilon, enough_function_value,
    crossing_volume, threshold: double;
    crossing_type, mutation_type: string;
    M, population_volume, max_iters, max_valueless_iters,
    preserved_high_positions, preserved_low_positions,
{вспомогательные}
    num_iters, start_iter, curr_iter: dword;
    indiv_vless: double;
    population: list_t;
    stop_flag: boolean;

{
    >>> ГЕНАРАЦИЯ НАЧАЛЬНОЙ ПОПУЛЯЦИИ <<<
}

function Generate_population(M, population_volume: dword): list_t;
var
    buf, str_ind_num: string;
    head, population: list_t;
    counter, ind_num: dword;
begin
    Randomize;
    buf := '#'; population := nil;
    for counter:=0 to population_volume-1 do
    begin
    {уникальный номер}
        repeat
            ind_num := trunc(exp(M*ln(2))*random());
            Str(ind_num, str_ind_num);
            str_ind_num := str_ind_num + '#';
        until (pos('#' + str_ind_num, buf) = 0);
        buf := buf + str_ind_num;
    {рождение уникальной особи}
        head := Make_individ(ind_num, M, 0, 4);
    {включение в популяцию}
        head^.next := population;
        population := head
    end;
    Generate_population := population
end;

{
    >>> КРИТЕРИИ ОСТАНОВА <<<
}

{num_iters, max_iters, quality_epsilon, max_valueless_iters, enough_function_value - Global Variables}

function Stop_1condition(var population: list_t): boolean;
begin
    Stop_1condition := false;
    if (num_iters >= max_iters) then
    begin
        Stop_1condition := true;
        if (mode = 0) then
        begin
            writeln(output_file,
                'Exceeded maximum iterations. Iteration ', num_iters);
            if (cmd_print = 1) then
                writeln('Exceeded maximum iterations. Iteration ', num_iters);
        end
        else
            writeln('Exceeded maximum iterations. Iteration ', num_iters)
    end
end;

{проверка на равенство прошлого значения с погрешностью. 1 - входит в окрестность нужное количество раз, 0 - иначе}
function Stop_2condition(var population: list_t;
                         var start_iter, curr_iter: dword;
                         var indiv_vless: double): boolean;
var
    buf: double;
begin
{дан отсортированный список}
    Stop_2condition := false;
    if (population <> nil) then
    begin
        buf := population^.fit;
        if (abs(buf - indiv_vless) >= quality_epsilon) then
        begin
            start_iter := curr_iter;
            indiv_vless := buf
        end
    end;
    if (curr_iter - start_iter + 1 >= max_valueless_iters) then
    begin
        Stop_2condition := true;
        if (mode = 0) then
        begin
            writeln(output_file,
                'Exceeded valueless iterations. Iteration ', num_iters);
            if (cmd_print = 1) then
                writeln('Exceeded valueless iterations. Iteration ',num_iters);
        end
        else
            writeln('Exceeded valueless iterations. Iteration ', num_iters)
    end
end;

function Stop_3condition(var population: list_t): boolean;
begin
{дан отсортированный список}
    Stop_3condition := false;
    if (population <> nil) then
    begin
        if (population^.fit >= enough_function_value) then
        begin
            Stop_3condition := true;
            if (mode = 0) then
            begin
                writeln(output_file,
                    'Exceeded enough function value. Iteration ', num_iters);
                if (cmd_print = 1) then
                    writeln('Exceeded enough function value. Iteration ', num_iters);
            end
            else
                writeln('Exceeded enough function value. Iteration ', num_iters)
        end
    end
end;

function Stop_criteria(var population: list_t; var start_iter, curr_iter: dword; var indiv_vless: double): boolean;
var
    flag1, flag2, flag3: boolean;
begin
    Stop_criteria := false;
    flag1 := Stop_1condition(population);
    flag2 := Stop_2condition(population, start_iter, curr_iter, indiv_vless);
    flag3 := Stop_3condition(population);
    if flag1 or flag2 or flag3 then
    begin
        Stop_criteria := true
    end
end;

{
    >>> СЕЛЕКЦИЯ <<<
}

{preserved_high_positions, preserved_low_positions, threshold - GV}
procedure Selection(var population: list_t);
var
    head_1, head_2: list_t;
    len_of_list, counter,
    kill_count, save_count: dword;
begin
{В популяции не менее (preserved_high_positions + preserved_low_positions) особей}
{Как минимум одна лучшая особь защищена от отбора}
    len_of_list := Length_list(population);
    save_count := round(len_of_list*threshold); {Количество особей, не участвующих в отборе}
    kill_count := len_of_list - save_count;
    counter := 2; {Положение head_2}
    head_1 := population; head_2 := head_1^.next;
    while   (len_of_list <> preserved_high_positions + preserved_low_positions)
        and (counter <= len_of_list - preserved_low_positions)
        and (kill_count > 0) do
    begin
    {Отсекаем часть особей}
        {Если соблюдён порог и найден кандидат}
        if  (counter > preserved_high_positions)
        {and (counter <= len_of_list - preserved_low_positions)}
        and (counter > save_count) then
        begin
            Kill_individ(head_2);
            head_2 := head_1^.next;
            kill_count := kill_count - 1;
            len_of_list := len_of_list - 1
        end
        else {Двигаемся к первому кандидату}
        begin
            counter := counter + 1;
            head_1 := head_2;
            head_2 := head_2^.next
        end
    end
end;

{
    >>> СКРЕЩИВАНИЕ <<<
}

{crossing_volume - GV}
{особи выбираются случайно. создаём новую популяцию. сначала добавляются дети, затем - родители}
{скрещивает две особи, добавляет их в указанную популяцию}
{buf - учёт особей в новой популяции}

{одноточечное (singlepoint) скрещивание}
{position - число от 1 до M}
function SP_crossing(num_1, num_2: dword; position: byte): pair_t;
var
    counter: byte;
    mask: dword;
begin
{создаём маску скрещивания}
    mask := 1;
    for counter:=1 to position-1 do
        mask := (mask shl 1) or 1;
{записываем ответ}
    SP_crossing.first := (num_1 and not mask) or (num_2 and mask);
    SP_crossing.second := (num_2 and not mask) or (num_1 and mask)
end;

{двуточечное (doublepoint) скрещивание}
{работает через SP_crossing}
{M >= pos_2 >= pos_1 >= 1}
function DP_crossing(num_1, num_2: dword; pos_1, pos_2: byte): pair_t;
var
    buf: byte;
    pair: pair_t;
begin
    if (pos_2 < pos_1) then
    begin
        buf := pos_2;
        pos_2 := pos_1;
        pos_1 := buf
    end;
    pair := SP_crossing(num_1, num_2, pos_2);
    DP_crossing := SP_crossing(pair.first, pair.second, pos_1)
end;

{универсальное скрещивание}
function UNI_crossing(num_1, num_2: dword): pair_t;
var
    prob_crossing, counter: byte;
    mask: dword;
begin
    prob_crossing := Random(100); {вероятность замены}
{создаём маску: если 1, то сохраняем бит на месте}
    mask := 0;
    for counter:=1 to M do
    begin
        if (Random(100) <= prob_crossing) then mask := mask + 1;
        mask := mask shl 1
    end;
{сохраняем ответ}
    UNI_crossing.first  := (num_1 and mask) or (num_2 and not mask);
    UNI_crossing.second := (num_2 and mask) or (num_1 and not mask)
end;

{однородное скрещивание}
function MONO_crossing(num_1, num_2: dword): pair_t;
var
    mask: dword;
begin
    mask := Random(MaxLongInt);
    MONO_crossing.first := (num_1 and mask) or (num_2 and (not mask));
    MONO_crossing.second := 0;
end;

{процедура скрещивания особей}
procedure Crossing(var population: list_t);
var
    buffer, str_ind_num: string;
    head_1, head_2: list_t;
    len_of_list, indiv_cross, ind_1, ind_2: dword;
    crossing_choice: word;
    indiv_pair: pair_t;
begin
    buffer := '#'; {кто участвовал в скрещивании}
    len_of_list := Length_list(population);
{количество особей, участвующих в скрещивании. >= 2}
{если indiv_cross mod 2 = 1 тогда на последнем шаге выбираем случайного родителя с потомками}
    indiv_cross := round(crossing_volume*len_of_list);
    if (indiv_cross >= 2) then
    while (indiv_cross > 0) and (Length_list(population) < population_volume) do
    begin
    {выбираем две уникальные позиции в популяции}
    {первого родителя}
        repeat
            ind_1 := trunc(1 + Random()*len_of_list);
            Str(ind_1, str_ind_num)
        until (pos('#' + str_ind_num + '#', buffer) = 0);
        buffer := buffer + str_ind_num + '#';
    {второго родителя}
        if (indiv_cross > 1) then
        begin
            repeat
                ind_2 := trunc(1 + Random()*len_of_list);
                Str(ind_2, str_ind_num)
            until (pos('#' + str_ind_num + '#', buffer) = 0);
            buffer := buffer + str_ind_num + '#';
            indiv_cross := indiv_cross - 2
        end
        else
        begin
        {берём случайного прошлого родителя}
            repeat
                ind_2 := trunc(1 + Random()*len_of_list);
                Str(ind_2, str_ind_num)
            until (pos('#' + str_ind_num + '#', buffer) <> 0);
            indiv_cross := indiv_cross - 1
        end;
    {находим особей в популяции}
        head_1 := Find_by_position(population, ind_1);
        head_2 := Find_by_position(population, ind_2);
    {проводим скрещивание для выбранных особей}
        if      (crossing_type = 'SP') then
            indiv_pair := SP_crossing(head_1^.num, head_2^.num, 1+Random(M))
        else if (crossing_type = 'DP') then
            indiv_pair := DP_crossing(head_1^.num, head_2^.num, 1+Random(M), 1+Random(M))
        else if (crossing_type = 'UNI') then
            indiv_pair := UNI_crossing(head_1^.num, head_2^.num)
        else if (crossing_type = 'MONO') then
            indiv_pair := MONO_crossing(head_1^.num, head_2^.num)
        else if (crossing_type = 'RANDOM') then
        begin
            crossing_choice := trunc(Random*100);
            if      (crossing_choice < 25) then 
                indiv_pair := SP_crossing(head_1^.num, head_2^.num, 1+Random(M))
            else if (crossing_choice < 50) then 
                indiv_pair := DP_crossing(head_1^.num, head_2^.num, 1+Random(M), 1+Random(M))
            else if (crossing_choice < 75) then 
                indiv_pair := UNI_crossing(head_1^.num, head_2^.num)
            else 
                indiv_pair := MONO_crossing(head_1^.num, head_2^.num)
        end;
    {присоединяем в конец популяции}
    if (indiv_pair.first  <> 0) and (Length_list(population) < population_volume) then
        Add_individ(population, Make_individ(indiv_pair.first,  M, 0, 4));
    if (indiv_pair.second <> 0) and (Length_list(population) < population_volume) then
        Add_individ(population, Make_individ(indiv_pair.second, M, 0, 4))
    end
end;

{
    >>> МУТАЦИЯ <<<
}


{изменение случайного бита}
procedure Mutate_1(var individ: list_t; mut_prob: word);
begin
    if (trunc(Random(100)) <= mut_prob) then
        individ^.num := individ^.num xor (1 shl Random(M))
end;

{перестановка двух случайных битов}
{first_point and second_point из [1,M]}
procedure Mutate_2(var individ: list_t; mut_prob: word; f_p, s_p: byte);
var
    diff: byte;
    mask_1, mask_2, buf: dword;
begin
    if (trunc(Random(100)) <= mut_prob) then
    begin
        if (s_p < f_p) then
        begin
            diff := s_p;
            s_p := f_p;
            f_p := diff
        end;
    {Пусть M >= s_p >= f_p >= 1}
        mask_1 := 1 shl (f_p - 1);
        mask_2 := 1 shl (s_p - 1);
        buf := individ^.num;
    {зануляем биты на выбранных позициях}
        individ^.num := individ^.num and (not (mask_1 or mask_2));
    {запоминаем биты на выбранных позициях и меняем их местами}
        diff := s_p - f_p;
        mask_1 := buf and mask_1; mask_1 := mask_1 shl diff;
        mask_2 := buf and mask_2; mask_2 := mask_2 shr diff;
    {создаем новое число}
        individ^.num := individ^.num or mask_1 or mask_2;
    end
end;

procedure Mutate_3(var individ: list_t; mut_prob: word);
var
    f_p, s_p, count: byte;
begin
    if (trunc(Random(100)) <= mut_prob) then
    begin
    {Пусть M >= s_p >= f_p >= 1}
        s_p := trunc(1+Random(M)); {случайная позиция}
        count := trunc(s_p / 2); {количество итераций}
        for f_p := 1 to count do
        begin
            Mutate_2(individ, 100, f_p, s_p);
            s_p := s_p - 1
        end
    end
end;

{variability - GV}
{мутируют некоторые случайные особи. выбирается случайная из трёх мутация}
procedure Mutation(var population: list_t);
var
    buffer, str_ind_num: string;
    mutate_count, len_of_list, position, ran_num: dword;
    mut_prob: word;
    head_pos: list_t;
begin
    mut_prob := trunc(Random(100)); {шанс мутации}
    len_of_list := Length_list(population);
    mutate_count := round(variability*len_of_list); {количество мутируемых}
{итерируем по количеству -> выбираем уникальную особь -> выбираем мутацию}
    buffer := '#'; {уже мутировавшие}
{запоминаем номера точек разбиения для всего списка}
    while (mutate_count > 0) do
    begin
    {выбираем случайную уникальную особь для мутации}
        repeat
            position := 1 + Random(len_of_list);
            Str(position, str_ind_num);
        until (pos('#' + str_ind_num + '#', buffer) = 0);
        buffer := buffer + str_ind_num + '#';
        head_pos := Find_by_position(population, position);
    {выбираем мутацию}
        if      (mutation_type = 'CHANGE') then 
            Mutate_1(head_pos, mut_prob)
        else if (mutation_type = 'SWAP') then 
            Mutate_2(head_pos, mut_prob, 1+Random(M), 1+Random(M))
        else if (mutation_type = 'REVERSE') then 
            Mutate_3(head_pos, mut_prob)
        else if (mutation_type = 'RANDOM') then
        begin
            ran_num := Random(100);
            if (ran_num < 33) then
                Mutate_1(head_pos, mut_prob)
            else if (ran_num < 66) then
                Mutate_2(head_pos, mut_prob, 1+Random(M), 1+Random(M))
            else
                Mutate_3(head_pos, mut_prob)
        end;
    {обновляем значения}
        Update_individ(head_pos, M, 0, 4);
    {следующая итерация}
        mutate_count := mutate_count - 1;
    end
end;

begin
{>> Константы}
    Randomize;
    Gather_info(variability, quality_epsilon, enough_function_value,
                crossing_volume, threshold, crossing_type, mutation_type,
                M, population_volume, max_iters, max_valueless_iters,
                preserved_high_positions, preserved_low_positions,
                mode, cmd_print);
{>> Рабочее тело}
{если Тестовый, то вывод в файл}
    if (mode = 0) then
    begin
        Assign(output_file, './output_file.txt');
        Rewrite(output_file)
    end;
{Генерация начальной популяции}
    population := Generate_population(M, population_volume);
{Подготовка к циклу}
    num_iters := 0;
    start_iter := 0;
    curr_iter := 0;
    indiv_vless := 0;
    stop_flag := false;
{Запуск цикла}
    while not stop_flag do
    begin
    {Сортировка особей по убыванию приспособленности}
    {После сортировки популяция есть двусвязный список}
        Insertion_sort(population);
        Write_list(population, M, mode, cmd_print, output_file);
    {Критерий останова}
        curr_iter := curr_iter + 1;
        stop_flag := Stop_criteria(population, start_iter, curr_iter, indiv_vless);
        if stop_flag then
        begin
        {Печать лучшей особи}
            if (mode = 1) then
            begin
                writeln('   x = ', population^.x   :0:12);
                writeln('f(x) = ', population^.fit :0:12)
            end
            else
            begin
                Delete_list(population^.next);
                Write_list(population, M, mode, cmd_print, output_file);
                close(output_file)
            end;
            Delete_list(population);
            Halt(0)
        end;
    {Селекция. Метод усечения}
        Selection(population);
    {Скрещивание}
        Crossing(population);
    {Мутация}
        Mutation(population);
    repeat
    {Удаляем дубликаты}
        Kill_duplicates(population);
    {Заполняем случайными особями по надобности}
        Crossing(population);
    until (Length_list(population) = population_volume);
    {Следующая итерация}
        num_iters := num_iters + 1
    end;
end.