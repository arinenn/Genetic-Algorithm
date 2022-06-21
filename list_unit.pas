{$H+}
unit list_unit;
interface
type
    individ_t = record
                    num: dword;
                    x: double;
                    fit: double;
                    previous: ^individ_t;
                    next: ^individ_t
                end;
    list_t = ^individ_t;

function Func(x: double): double;
function Num_2_bin(num: dword): string;
function Append_length(var bin: string; len: dword): string;
function Make_individ(number, M, A_SEG, B_SEG: dword): list_t;
procedure Write_list(spisok: list_t; M: dword;
                     mode, cmd_print: byte;
                     var output_file: text);
procedure Delete_list(var list: list_t);
procedure Swap(var elem_1, elem_2: list_t);
procedure Insertion_sort(var population: list_t);
procedure Kill_individ(var head: list_t);
procedure Add_individ(var population: list_t; individ: list_t);
function Length_list(var population: list_t): dword;
function Find_by_position(var population: list_t; position: dword): list_t;
procedure Update_individ(var individ: list_t; M, A_SEG, B_SEG: dword);
procedure Kill_duplicates(var population: list_t);

implementation

function Func(x: double): double;
begin
    Func := x*(x-1.1)*(x-1.1)*(x-1.1)*(x-1.1)*(x-1.1)*
              (x-1.2)*(x-1.2)*(x-1.2)*(x-1.2)*
              (x-1.3)*(x-1.3)*(x-1.3)*cos(x+100)
end;

function Num_2_bin(num: dword): string;
var
    digit: char;
    buf: string;
begin
    buf := '';
    repeat
        case (num mod 2) of
            1: digit := '1';
            0: digit := '0'
        end;
        num := num div 2;
        buf := digit + buf;
    until (num=0);
    Num_2_bin := buf
end;

function Append_length(var bin: string; len: dword): string;
var
    buf: string;
begin
    buf := bin;
    while (Length(buf)<len)do
        buf := '0' + buf;
    Append_length := buf
end;

function Make_individ(number, M, A_SEG, B_SEG: dword): list_t;
var
    head: list_t;
begin
    New(head);
    head^.num := number;
    head^.x := A_SEG + (number) * (B_SEG - A_SEG) / exp((M)*ln(2));
    head^.fit := Func(head^.x);
    head^.previous := nil;
    head^.next := nil;
    Make_individ := head
end;

procedure Write_list(spisok: list_t; M: dword;
                     mode, cmd_print: byte;
                     var output_file: text);
var
    offset: dword;
    buf, head_bin: string;
    head: list_t;
begin
    Str(trunc(exp(M*ln(2))), buf);
    offset := Length(buf);
    if (spisok <> nil) then
    begin
        head := spisok;
        repeat
        {вывод характеристик}
            head_bin := Num_2_bin(head^.num);
            head_bin := Append_length(head_bin, M);
        {если режим Test - вывод в файл}
            if (mode = 0) then
            begin
                write(output_file, head^.num:offset, ' ');
                write(output_file, head_bin); write(output_file, ' ');
                write(output_file, head^.x:0:12, ' ', head^.fit:0:12); writeln(output_file)
            end;
        {возврат в консоль по требованию}
            if (cmd_print = 1) then
            begin
                write(head^.num:offset, ' ');
                write(head_bin); write(' ');
                write(head^.x:0:12, ' ', head^.fit:0:12); writeln;
            end;
        {переход к следующей особи}
            head := head^.next
        until (head = nil);
        if (Length_list(spisok) <> 1) then
        begin
            if (mode = 0) then
                writeln(output_file, Length_list(spisok));
            if (cmd_print = 1) then
                writeln(Length_list(spisok))
        end
    end
end;

procedure Delete_list(var list: list_t);
begin
    if (list<>nil) then
    begin
        Delete_list(list^.next);
        Dispose(list);
        list := nil
    end
end;

procedure Swap(var elem_1, elem_2: list_t);
var
    buf: individ_t;
begin
    buf := elem_1^;

    elem_1^.num := elem_2^.num;
    elem_1^.x := elem_2^.x;
    elem_1^.fit := elem_2^.fit;
    
    elem_2^.num := buf.num;
    elem_2^.x := buf.x;
    elem_2^.fit := buf.fit;
end;

procedure Insertion_sort(var population: list_t);
var
    co_1, co_2, len_list: integer;
    buf, head, head_0: list_t;
begin
{переназначаем ссылки обратно}
    head := population;
    head_0 := nil;
    while (head <> nil) do
    begin
        head^.previous := head_0;
        head_0 := head;
        head := head^.next
    end;
{начинаем сортировку}
    head := population^.next;
    len_list := Length_list(population);
    for co_1:=2 to len_list do
    begin
        buf := head;
        co_2 := co_1;
        while (co_2 > 1) and (head^.fit > head^.previous^.fit) do
        begin
            
            Swap(head, head^.previous);
            head := head^.previous;
            co_2 := co_2 - 1
        end;
        head := buf^.next
    end;
{переназначем ссылки обратно}
    head := population;
    head_0 := nil;
    while (head <> nil) do
    begin
        head^.previous := head_0;
        head_0 := head;
        head := head^.next
    end;
end;

{дан двусвязный список, удалить заданную вершину}
procedure Kill_individ(var head: list_t);
var
    buf: list_t;
begin
    buf := head;
    if (head^.next = nil) and (head^.previous = nil) then
    begin
        Dispose(head);
        head := nil
    end
    else if (head^.previous = nil) then
    begin
        head := head^.next;
        Dispose(buf);
        head^.previous := nil
    end
    else if (head^.next = nil) then
    begin
        head^.previous^.next := nil;
        head := nil;
        Dispose(buf)
    end
    else
    begin
        head^.previous^.next := head^.next;
        head^.next^.previous := head^.previous;
        head := head^.next;
        Dispose(buf)
    end
end;

{добавляет в конец}
procedure Add_individ(var population: list_t; individ: list_t);
var
    head: list_t;
begin
    if (population <> nil) then
    begin
        head := population;
        while (head^.next <> nil) do
            head := head^.next;
        head^.next := individ;
        individ^.previous := head
    end
end;

function Length_list(var population: list_t): dword;
var
    buf: dword;
    head: list_t;
begin
    head := population; buf := 0;
    while (head <> nil) do
    begin
        buf := buf + 1;
        head := head^.next
    end;
    Length_list := buf
end;

function Find_by_position(var population: list_t; position: dword): list_t;
var
    buf: list_t;
    counter: dword;
begin
{если нашёл, то возвр. ссылку на узел с номером num; если не нашёл - nil}
    Find_by_position := nil;
    buf := population;
    counter := 0;
    while (buf <> nil) do
    begin
        counter := counter + 1;
        if (counter = position) then
        begin
            Find_by_position := buf;
            Break
        end;
        buf := buf^.next
    end
end;

{обновляем в соответствии с генетическим материалом}
procedure Update_individ(var individ: list_t; M, A_SEG, B_SEG: dword);
begin
    individ^.x := A_SEG + (individ^.num) * (B_SEG - A_SEG) / exp((M)*ln(2));
    individ^.fit := Func(individ^.x)
end;

procedure Kill_duplicates(var population: list_t);
var
    head: list_t;
    buffer, str_ind_num: string;
begin
    if (population <> nil) then
    begin
        head := population;
        buffer := '#';
        repeat
            Str(head^.num, str_ind_num);
            if (pos('#'+str_ind_num+'#', buffer) = 0) then
            begin
                buffer := buffer + str_ind_num + '#';
                head := head^.next
            end
            else
                Kill_individ(head) {head := head^.next}
        until (head = nil)
    end
end;

end.