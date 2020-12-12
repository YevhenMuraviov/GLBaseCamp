import re


def count_holes(line):
    # gets number from a line and counts holes in it
    # returns integer with quantity of holes or string 'error' if failed

    regexp = '^[-]?(\d+)$'
    one_hole_numbers = ('4690')
    count = 0
    line_type = type(line)

    if line_type == int:
        line = str(line)
    elif line_type != str:
        return('error')
    parsing_result = re.search(regexp, line)

    if parsing_result:
        number = parsing_result.group(1).lstrip('0')
    else:
        return('error')

    for hole_number in one_hole_numbers:
        count += number.count(hole_number)

    count += number.count('8') * 2
    return(count)


if __name__ == '__main__':
    check_line = '-0001234567890123'
    print(count_holes(check_line))

