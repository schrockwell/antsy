defmodule AntsyTest do
  use ExUnit.Case
  doctest Antsy

  test "decodes plain text without any escape codes" do
    assert Antsy.decode("Hello, world!") == {["Hello, world!"], ""}
  end

  test "decodes text with inline formatting" do
    string = IO.ANSI.format([:bright, :underline, "Hello, world!"]) |> to_string()

    assert Antsy.decode(string) ==
             {[:bright, :underline, "Hello, world!", :reset], ""}
  end

  test "returns a remainder when the escape sequence is not yet complete" do
    assert Antsy.decode("hello\e[") == {["hello"], "\e["}
  end

  test "decodes :invalid for a bad :cursor sequence" do
    assert Antsy.decode("\e[1H") == {[:invalid], ""}
    assert Antsy.decode("\e[1;2;3H") == {[:invalid], ""}
  end

  test "decodes :invalid for a bad :color sequence" do
    assert Antsy.decode("\e[123m") == {[:invalid], ""}
    assert Antsy.decode("\e[123;456m") == {[:invalid], ""}
  end

  test "decodes an unknown sequence" do
    assert Antsy.decode("\e[=0h") == {[{:unknown, "\e[=0h"}], ""}
  end

  test "decodes :home" do
    assert_decode(:home)
  end

  test "decodes :cursor" do
    assert_decode(:cursor, [1, 2])
    assert_decode(:cursor, [12, 34])
  end

  test "decodes :cursor_up/down/left/right" do
    assert_decode(:cursor_up, [1])
    assert_decode(:cursor_down, [1])
    assert_decode(:cursor_left, [1])
    assert_decode(:cursor_right, [1])

    assert_decode("\e[A", :cursor_up, [1])
    assert_decode("\e[B", :cursor_down, [1])
    assert_decode("\e[C", :cursor_right, [1])
    assert_decode("\e[D", :cursor_left, [1])
  end

  test "decodes basic modes" do
    assert_decode(:reset)
    assert_decode(:bright)
    assert_decode(:faint)
    assert_decode(:italic)
    assert_decode(:underline)
    assert_decode(:blink_slow)
    assert_decode(:blink_rapid)
    assert_decode(:inverse)
    assert_decode(:conceal)
    assert_decode(:crossed_out)
    assert_decode(:primary_font)
    assert_decode(:font_1)
    assert_decode(:font_2)
    assert_decode(:font_3)
    assert_decode(:font_4)
    assert_decode(:font_5)
    assert_decode(:font_6)
    assert_decode(:font_7)
    assert_decode(:font_8)
    assert_decode(:font_9)
    assert_decode(:normal)
    assert_decode(:not_italic)
    assert_decode(:no_underline)
    assert_decode(:blink_off)
    assert_decode(:inverse_off)
    assert_decode(:default_color)
    assert_decode(:default_background)
    assert_decode(:framed)
    assert_decode(:encircled)
    assert_decode(:overlined)
    assert_decode(:not_framed_encircled)
    assert_decode(:not_overlined)
  end

  test "decodes 256-colors" do
    assert_decode(:color, [123])
    assert_decode(:color_background, [123])
  end

  test "decodes an array of individual character strings" do
    chars = ["\e", "[", "H"]

    assert {[:home], ""} =
             Enum.reduce(chars, {[], ""}, fn char, {acc, remainder} ->
               {new_data, new_remainder} = Antsy.decode(remainder <> char)
               {acc ++ new_data, new_remainder}
             end)
  end

  defp assert_decode(name) do
    string = apply(IO.ANSI, name, [])
    assert Antsy.decode(string) == {[name], ""}
  end

  defp assert_decode(name, args) do
    string = apply(IO.ANSI, name, args)
    assert Antsy.decode(string) == {[{name, args}], ""}
  end

  defp assert_decode(string, name, args) do
    assert Antsy.decode(string) == {[{name, args}], ""}
  end
end
