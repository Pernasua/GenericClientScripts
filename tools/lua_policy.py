"""Structural checks for the catalog's behavior API, using the installed Lua lexer."""

from dataclasses import dataclass
import re

from pygments.lexers import LuaLexer
from pygments.token import Comment, String, Text


@dataclass(frozen=True)
class Token:
    start: int
    end: int
    value: str
    quoted: bool = False


def string_value(source: str) -> str:
    if source.startswith("["):
        delimiter = source.index("[", 1) + 1
        return source[delimiter:-delimiter].removeprefix("\n")
    escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v"}

    def decode(match: re.Match[str]) -> str:
        value = match[0][1:]
        if value.startswith("z"):
            return ""
        if value.startswith("x"):
            return chr(int(value[1:], 16))
        if value.startswith("u{"):
            return chr(int(value[2:-1], 16))
        if value.isdecimal():
            return chr(int(value))
        return escapes.get(value, value)

    return re.sub(r"\\(?:\d{1,3}|x[0-9a-fA-F]{2}|u\{[0-9a-fA-F]+\}|z\s*|[\s\S])", decode, source[1:-1])


def tokens(source: str) -> list[Token]:
    chunks = list(LuaLexer().get_tokens_unprocessed(source))
    result = []
    index = 0
    while index < len(chunks):
        start, kind, value = chunks[index]
        index += 1
        if kind in Comment or kind in Text:
            continue
        end = start + len(value)
        if kind in String:
            while index < len(chunks) and chunks[index][0] == end and chunks[index][1] in String:
                end += len(chunks[index][2])
                index += 1
            result.append(Token(start, end, string_value(source[start:end]), True))
        else:
            result.append(Token(start, end, value))
    return result


@dataclass
class Frame:
    opening: str
    owner: str
    argument: int = 1


def assigned_name(items: list[Token], index: int) -> str:
    if index < 2 or items[index - 1].value != "=":
        return ""
    if items[index - 2].value == "]" and index >= 4 and items[index - 3].quoted:
        return items[index - 3].value
    return items[index - 2].value


def field_value(items: list[Token], index: int) -> Token | None:
    after = index + (2 if items[index].quoted else 1)
    if after + 1 < len(items) and items[after].value == "=":
        return items[after + 1]
    return None


def gc_call(items: list[Token], index: int) -> str:
    if index >= 3 and [item.value for item in items[index - 3:index - 1]] == ["gc", "."]:
        return items[index - 1].value
    return ""


def violations(source: str) -> list[tuple[int, str]]:
    items = tokens(source)
    stack: list[Frame] = []
    errors = []
    skilling = []
    combat = False
    for index, token in enumerate(items):
        line = source.count("\n", 0, token.start) + 1
        parent = stack[-1] if stack else None
        if token.quoted and parent and parent.owner == "activity" and parent.argument == 1:
            if token.value == "skilling":
                skilling.append(line)
        value = field_value(items, index)
        table = next((frame for frame in reversed(stack) if frame.opening == "{"), None)
        policy_member = index >= 2 and items[index - 2].value == "policy" and items[index - 1].value in (".", "[")
        policy_table = table and (table.owner == "policy" or table.owner.endswith("_policy"))
        if value and token.value == "breaks" and not policy_member and not policy_table:
            errors.append((line, "Declare breaks in a policy table or use gc.intent."))
        if token.value == "interrupt_on_dialogue" and value:
            errors.append((line, "Use interrupt_on = { dialogue = true }."))
        if value and token.value == "type" and table and table.owner == "action":
            combat = combat or value.quoted and value.value.startswith("combat.")
        if token.quoted:
            continue
        if token.value in ("(", "[", "{"):
            owner = gc_call(items, index) if token.value == "(" else assigned_name(items, index)
            if token.value == "{" and parent and parent.owner == "activity" and parent.argument == 2:
                owner = "policy"
            stack.append(Frame(token.value, owner))
        elif token.value in (")", "]", "}"):
            stack.pop()
        elif token.value == "," and parent and parent.opening == "(":
            parent.argument += 1
    if combat:
        errors.extend((line, "Combat scripts must declare combat activity with their intended policy.") for line in skilling)
    return errors
