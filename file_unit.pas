{$H+}
unit file_unit;
interface
type
    arr_of_string_t = array of string;
    string_pair_t = record
                        name: string;
                        value: string;
                    end;
    arr_of_string_pair_t = array of string_pair_t;

function Make_pair(name_pair: string; var flag: boolean): string_pair_t;
function Divide_row_by_words(your_row: string): arr_of_string_t;
procedure Gather_info
    (var variability, quality_epsilon, enough_function_value,
        crossing_volume, threshold: double;
     var crossing_type, mutation_type: string;
     var M, population_volume, max_iters, max_valueless_iters,
        preserved_high_positions, preserved_low_positions: dword;
     var mode, cmd_print: byte);

implementation
uses sysutils;

function Divide_row_by_words(your_row: string): arr_of_string_t;
var
    logged_char: char;
    logged_string: string;
    logged_array: arr_of_string_t;
    counter, length_of_array: integer;
    flaggie: boolean;
begin
    flaggie := False;
    length_of_array := 0;
    logged_string := '';
    for counter:=1 to Length(your_row) do
    begin
        logged_char := your_row[counter];
        if (not ((ord(logged_char) = 13) or (ord(logged_char) = 9)
            or   (ord(logged_char) = 32) or (ord(logged_char) = 10)))
        then
        begin
            flaggie := False;
            if (logged_char <> '#') then
                logged_string := logged_string + logged_char;
            if (counter = Length(your_row)) or (logged_char = '#') then
            begin
                length_of_array := length_of_array + 1;
                SetLength(logged_array, length_of_array);
                logged_array[length_of_array-1] := logged_string;
                Break
            end
        end
        else
        begin
            if (not flaggie) and (logged_string <> '') then
            begin
                length_of_array := length_of_array + 1;
                SetLength(logged_array, length_of_array);
                logged_array[length_of_array-1] := logged_string;
                logged_string := '';
                flaggie := True;
            end
        end
    end;
    if (length_of_array = 0) then
    begin
        SetLength(logged_array, 1);
        logged_array[0] := '';
    end;
    Divide_row_by_words := logged_array
end;

{получает элемент строки, выводит ошибки, возвращает пару имя+значение}
{остановка программы после всех ошибок с файлом (!)}
function Make_pair(name_pair: string; var flag: boolean): string_pair_t;
var
    part_name, part_value: string;
    counter: integer;
    flag_equality, flag_value_equality, flag_halt: boolean;
begin
{делим строку на пару}
    part_name := ''; part_value := '';
    flag_equality := False;
    flag_value_equality := False;
    for counter:=1 to Length(name_pair) do
    begin
        if (name_pair[counter] = '=') then
        begin
            if (not flag_equality) then
                flag_equality := True
            else
            begin
                flag_value_equality := True
            end
        end
        else
        begin
            if (not flag_equality) then
                part_name := part_name + name_pair[counter]
            else
                part_value := part_value + name_pair[counter]
        end
    end;
{проверяем строку, если она не пустая}
    flag_halt := False;
    if (name_pair <> '') then
    if flag_equality then
    begin
        if flag_value_equality then
        begin
            writeln('"', part_name, '=', part_value, '" has multiple "=" signs.');
            flag_halt := True
        end
        else if (part_name = '') and (part_value = '') then
        begin
            writeln('"=" has no name and no value.');
            flag_halt := True
        end
        else if (part_name = '') then
        begin
            writeln('"=', part_value, '" has no name.');
            flag_halt := True
        end
        else if (part_value = '') then
        begin
            writeln('"', part_name, '=" has no value.');
            flag_halt := True
        end
    end
    else
    begin
        writeln('"', part_name, '" is not equality.');
        flag_halt := True
    end;
{вывод}
    flag := flag_halt;
    Make_pair.name := part_name;
    Make_pair.value := part_value
end;

procedure Gather_info
    (var variability, quality_epsilon, enough_function_value,
        crossing_volume, threshold: double;
     var crossing_type, mutation_type: string;
     var M, population_volume, max_iters, max_valueless_iters,
        preserved_high_positions, preserved_low_positions: dword;
     var mode, cmd_print: byte);
var
    info_file: text;
    row_file: string;
    control: byte;
    counter, length_arr_of_pairs: dword;

    flag_halt_reader, flag_halt_value, flag_halt_assign,
    f_variability, f_quality_epsilon, f_enough_function_value,
    f_crossing_volume, f_threshold, f_M, f_population_volume,
    f_max_iters, f_max_valueless_iters,
    f_crossing_type, f_mutation_type,
    f_preserved_high_positions, f_preserved_low_positions,
    f_mode, f_cmd_print: boolean;

    component_pair: string_pair_t;
    row_components: arr_of_string_t;
    arr_of_pairs: arr_of_string_pair_t;
begin
    if FileExists('./config.txt') then
        Assign(info_file, './config.txt')
    else
    begin
        writeln('ERROR: File "config.txt" not found.');
        Halt(1)
    end;
{режим чтения}
    Reset(info_file);
{считываем построчно}
{разбиваем на составляющие}
{ведём отчет введённых переменных}
    length_arr_of_pairs := 0;
    while (not eof(info_file)) do
    begin
        readln(info_file, row_file);
        row_components := Divide_row_by_words(row_file);
        for counter:=0 to Length(row_components)-1 do
        begin
            component_pair := Make_pair(row_components[counter], flag_halt_reader);
            length_arr_of_pairs := length_arr_of_pairs + 1;
            SetLength(arr_of_pairs, length_arr_of_pairs);
            arr_of_pairs[length_arr_of_pairs - 1] := component_pair;
        end
    end;
{получили массив из собранных пар. все ошибки были выведены}
    if flag_halt_reader and (row_components[0] <> '') then
    begin
        writeln('ERROR: Wrong variable format.');
        Halt(1)
    end
    else
    begin
{сохраняем ключевые значения, проверяя на верность правой части; если не хватает, то соответствующая ошибка}
    flag_halt_value := False;
        f_variability := False;
        f_quality_epsilon := False;
        f_enough_function_value := False;
        f_crossing_volume := False;
        f_threshold := False;
        f_crossing_type := False;
        f_mutation_type := False;
        f_M := False;
        f_population_volume := False;
        f_max_iters := False;
        f_max_valueless_iters := False;
        f_preserved_high_positions := False;
        f_preserved_low_positions := False;
        f_mode := False;
        f_cmd_print := False;
    for counter:=0 to Length(arr_of_pairs)-1 do
    begin
        control := 0;
        component_pair := arr_of_pairs[counter];
        case component_pair.name of
    {можно указывать несуществующие переменные, но в программе они не участвуют}
        'variability':
            begin
                Val(component_pair.value, variability, control);
                f_variability := True
            end;
        'quality_epsilon':
            begin
                Val(component_pair.value, quality_epsilon, control);
                f_quality_epsilon := True
            end;
        'enough_function_value':
            begin
                Val(component_pair.value, enough_function_value, control);
                f_enough_function_value := True
            end;
        'crossing_volume':
            begin
                Val(component_pair.value, crossing_volume, control);
                f_crossing_volume := True
            end;
        'threshold':
            begin
                Val(component_pair.value, threshold, control);
                f_threshold := True
            end;
        'M':
            begin
                Val(component_pair.value, M, control);
                f_M := True
            end;
        'population_volume':
            begin
                Val(component_pair.value, population_volume, control);
                f_population_volume := True
            end;
        'crossing_type':
            begin
                crossing_type := component_pair.value;
                f_crossing_type := True
            end;
        'mutation_type':
            begin
                mutation_type := component_pair.value;
                f_mutation_type := True
            end;
        'max_iters':
            begin
                Val(component_pair.value, max_iters, control);
                f_max_iters := True
            end;
        'max_valueless_iters':
            begin
                Val(component_pair.value, max_valueless_iters, control);
                f_max_valueless_iters := True
            end;
        'preserved_high_positions':
            begin
                Val(component_pair.value, preserved_high_positions, control);
                f_preserved_high_positions := True
            end;
        'preserved_low_positions':
            begin
                Val(component_pair.value, preserved_low_positions, control);
                f_preserved_low_positions := True
            end;
        'mode':
            begin
                Val(component_pair.value, mode, control);
                f_mode := True
            end;
        'cmd_print':
            begin
                Val(component_pair.value, cmd_print, control);
                f_cmd_print := True
            end;
        end;
        if (control <> 0) then
        begin
            writeln('"', component_pair.name, '" has wrong value.');
            flag_halt_value := True
        end
    end;
    if flag_halt_value then
    begin
        writeln('ERROR: Variables are assigned with wrong value.');
        Halt(1)
    end;
{можно опустить population_volume, quality_epsilon}
    flag_halt_assign := False;
    if not f_variability then
        begin
            writeln('"variability" is not assigned.');
            flag_halt_assign := True
        end
        else if (variability > 1) or (variability < 0) then
        begin
            writeln('"variability" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_quality_epsilon then
        begin
            quality_epsilon := 0.00001 {по умолчанию}
        end;
    if not f_enough_function_value then
        begin
            writeln('"enough_function_value" is not assigned.');
            flag_halt_assign := True
        end;
    if not f_crossing_volume then
        begin
            writeln('"crossing_volume" is not assigned.');
            flag_halt_assign := True
        end
        else if (crossing_volume > 1) or (crossing_volume < 0) then
        begin
            writeln('"crossing_volume" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_threshold then
        begin
            writeln('"threshold" is not assigned.');
            flag_halt_assign := True
        end
        else if (threshold > 1) or (threshold < 0) then
        begin
            writeln('"threshold" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_crossing_type then
        begin
            crossing_type := 'RANDOM'
        end
        else if (crossing_type <> 'SP') and
                (crossing_type <> 'DP') and
                (crossing_type <> 'UNI') and
                (crossing_type <> 'MONO') then
        begin
            writeln('"crossing_type" - invalid value assigned.');
            flag_halt_assign := True
        end;
    if not f_mutation_type then
        begin
            mutation_type := 'RANDOM'
        end
        else if (mutation_type <> 'CHANGE') and
                (mutation_type <> 'SWAP') and
                (mutation_type <> 'REVERSE') then
        begin
            writeln('"mutation_type" - invalid value assigned.');
            flag_halt_assign := True
        end;
    if not f_M then
        begin
            writeln('"M" is not assigned.');
            flag_halt_assign := True
        end
        else if (M < 1) or (M > 32) then
        begin
            writeln('"M" is out of acceptable values [1, 32].');
            flag_halt_assign := True
        end;
    if not f_population_volume then
        begin
            writeln('"population_volume" is not assigned.');
            flag_halt_assign := True
        end
        else if (population_volume < 1) then
        begin
            writeln('"population_volume" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_max_iters then
        begin
            writeln('"max_iters" is not assigned.');
            flag_halt_assign := True
        end
        else if (max_iters < 1) then
        begin
            writeln('"max_iters" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_max_valueless_iters then
        begin
            writeln('"max_valueless_iters" is not assigned.');
            flag_halt_assign := True
        end
        else if (max_valueless_iters < 1) then
        begin
            writeln('"max_valueless_iters" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_preserved_high_positions then
        begin
            writeln('"preserved_high_positions" is not assigned.');
            flag_halt_assign := True
        end
        else if (preserved_high_positions < 1) then
        begin
            writeln('"preserved_high_positions" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_preserved_low_positions then
        begin
            writeln('"preserved_low_positions" is not assigned.');
            flag_halt_assign := True
        end
        else if (preserved_low_positions < 1) then
        begin
            writeln('"preserved_low_positions" is out of acceptable values.');
            flag_halt_assign := True
        end;
    if not f_mode then
        begin
            writeln('"mode" is not assigned.');
            flag_halt_assign := True
        end;
    if not f_cmd_print then
        begin
            writeln('"cmd_print" is not assigned.');
            flag_halt_assign := True
        end
    end;
{дополнительная проверка на соблюдение верхних и нижних пределов}
    if  f_population_volume
    and f_preserved_high_positions
    and f_preserved_low_positions then
    begin
        if not (
population_volume >= (preserved_high_positions + preserved_low_positions)
                ) then
        begin
            writeln(
'(!) population_volume < preserved_high_positions + preserved_high_positions.'
                    );
            flag_halt_assign := True
        end
    end;
{последняя остановка, иначе - переменные были считаны успешно}
    if flag_halt_assign then
    begin
        writeln(
'ERROR: Important variables are not assigned or assigned with wrong values.'
                );
        Halt(1)
    end
    else
        writeln('Information gathered correctly.')
end;

end.