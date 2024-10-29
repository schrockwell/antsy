defmodule Antsy.Sequence do
  @moduledoc false

  defmacro defsequence(name, code) do
    quote bind_quoted: [name: name, code: code] do
      defp decode_sequence(unquote(code)) do
        unquote(name)
      end
    end
  end
end

defmodule Antsy do
  @moduledoc """
  Decodes ANSI escape sequences.
  """

  import Antsy.Sequence

  @esc 0x1B

  @type ansidata ::
          String.t()
          | {:unknown, String.t()}
          | :invalid
          | :home
          | {:cursor, [non_neg_integer]}
          | {:cursor_up, [non_neg_integer]}
          | {:cursor_down, [non_neg_integer]}
          | {:cursor_left, [non_neg_integer]}
          | {:cursor_right, [non_neg_integer]}
          | :reset
          | :bright
          | :faint
          | :italic
          | :underline
          | :blink_slow
          | :blink_rapid
          | :inverse
          | :conceal
          | :crossed_out
          | :primary_font
          | :font_1
          | :font_2
          | :font_3
          | :font_4
          | :font_5
          | :font_6
          | :font_7
          | :font_8
          | :font_9
          | :normal
          | :not_italic
          | :no_underline
          | :blink_off
          | :inverse_off
          | :default_color
          | :default_background
          | :framed
          | :encircled
          | :overlined
          | :not_framed_encircled
          | :not_overlined
          | {:color, [0..255]}
          | {:color_background, [0..255]}
          | :black
          | :light_black
          | :black_background
          | :light_black_background
          | :red
          | :light_red
          | :red_background
          | :light_red_background
          | :green
          | :light_green
          | :green_background
          | :light_green_background
          | :yellow
          | :light_yellow
          | :yellow_background
          | :light_yellow_background
          | :blue
          | :light_blue
          | :blue_background
          | :light_blue_background
          | :magenta
          | :light_magenta
          | :magenta_background
          | :light_magenta_background
          | :cyan
          | :light_cyan
          | :cyan_background
          | :light_cyan_background
          | :white
          | :light_white
          | :white_background
          | :light_white_background

  @doc """
  Extracts ANSI escape sequences from a string.

  Returns a tuple containing a list of decoded data, and a string of any remaining data that could not be completely
  decoded. When decoding a stream of data (e.g. from TCP or stdin), the caller should keep track of the remainder and
  prepend it to the next chunk of data for further decoding.

  Each element in the decoded data list is one of the following:

  - string - plain, unescaped text
  - atom - escape sequences with no parameters
  - tuple - escape sequences with parameters (256 colors, cursor movement, etc.)
  - `{:unknown, string}` - escape sequences that are not recognized (PRs welcome!)
  - `:invalid` - escape sequences that are recognized but have invalid parameters

  The escape sequence names largely follow the conventions established by the `IO.ANSI` module, but may not be a
  one-to-one match.

  ## Example

      iex> Antsy.decode("Hello, \\e[1mworld!\\e[0m")
      {["Hello, ", :bright, "world!", :reset], ""}
  """
  @spec decode(String.t()) :: {list(ansidata), String.t()}
  def decode(string) when is_binary(string) do
    decode_next(string, {:text, ""}, [])
  end

  # Accumulate text on text
  defp decode_next(<<char, rest::binary>>, {:text, acc}, results) when char != @esc do
    decode_next(rest, {:text, acc <> <<char>>}, results)
  end

  # Switch from test to escape mode
  defp decode_next(<<@esc, rest::binary>>, {:text, ""}, results) do
    decode_next(rest, {:esc, <<@esc>>}, results)
  end

  defp decode_next(<<@esc, rest::binary>>, {:text, acc}, results) do
    decode_next(rest, {:esc, <<@esc>>}, [acc | results])
  end

  # H and f - move cursor
  defp decode_next(<<ending, rest::binary>>, {:esc, "\e[" <> args}, results)
       when ending in [?H, ?f] do
    token =
      case String.split(args, ";") do
        [""] ->
          :home

        [line, column] ->
          with {line, ""} <- Integer.parse(line),
               {column, ""} <- Integer.parse(column) do
            {:cursor, [line, column]}
          else
            _ -> :invalid
          end

        _ ->
          :invalid
      end

    decode_next(rest, {:text, ""}, [token | results])
  end

  @cursor_movements [
    cursor_up: ?A,
    cursor_down: ?B,
    cursor_right: ?C,
    cursor_left: ?D
    # TODO: E, F, G?
  ]

  for {name, char} <- @cursor_movements do
    defp decode_next(<<unquote(char), rest::binary>>, {:esc, "\e["}, results) do
      decode_next(rest, {:text, ""}, [{unquote(name), [1]} | results])
    end

    defp decode_next(<<unquote(char), rest::binary>>, {:esc, "\e[" <> arg}, results) do
      token =
        case Integer.parse(arg) do
          {count, _} when count >= 1 -> {unquote(name), [count]}
          :error -> :invalid
        end

      decode_next(rest, {:text, ""}, [token | results])
    end
  end

  defsequence(:reset, 0)
  defsequence(:bright, 1)
  defsequence(:faint, 2)
  defsequence(:italic, 3)
  defsequence(:underline, 4)
  defsequence(:blink_slow, 5)
  defsequence(:blink_rapid, 6)
  defsequence(:inverse, 7)
  defsequence(:conceal, 8)
  defsequence(:crossed_out, 9)
  defsequence(:primary_font, 10)

  for font_n <- [1, 2, 3, 4, 5, 6, 7, 8, 9] do
    defsequence(:"font_#{font_n}", font_n + 10)
  end

  defsequence(:normal, 22)
  defsequence(:not_italic, 23)
  defsequence(:no_underline, 24)
  defsequence(:blink_off, 25)
  defsequence(:inverse_off, 27)

  colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

  for {color, code} <- Enum.with_index(colors) do
    defsequence(color, code + 30)
    defsequence(:"light_#{color}", code + 90)
    defsequence(:"#{color}_background", code + 40)
    defsequence(:"light_#{color}_background", code + 100)
  end

  defsequence(:default_color, 39)
  defsequence(:default_background, 49)
  defsequence(:framed, 51)
  defsequence(:encircled, 52)
  defsequence(:overlined, 53)
  defsequence(:not_framed_encircled, 54)
  defsequence(:not_overlined, 55)

  defp decode_sequence(_), do: :invalid

  # m - color/graphic mode
  # 38;5; - 256-color foreground
  defp decode_next(<<"m", rest::binary>>, {:esc, "\e[38;5;" <> id}, results) do
    token =
      with {id, ""} <- Integer.parse(id), id in 0..255 do
        {:color, [id]}
      else
        _ -> :invalid
      end

    decode_next(rest, {:text, ""}, [token | results])
  end

  # 48;5; - 256-color background
  defp decode_next(<<"m", rest::binary>>, {:esc, "\e[48;5;" <> id}, results) do
    token =
      with {id, ""} <- Integer.parse(id), id in 0..255 do
        {:color_background, [id]}
      else
        _ -> :invalid
      end

    decode_next(rest, {:text, ""}, [token | results])
  end

  defp decode_next(<<"m", rest::binary>>, {:esc, "\e[" <> args}, results) do
    tokens =
      args
      |> String.split(";")
      |> Enum.map(&decode_mode/1)
      |> Enum.reverse()

    if Enum.any?(tokens, &(&1 == :invalid)) do
      decode_next(rest, {:text, ""}, [:invalid | results])
    else
      decode_next(rest, {:text, ""}, tokens ++ results)
    end
  end

  # unknown escape sequence
  defp decode_next(<<unknown, rest::binary>>, {:esc, "\e" <> _args = seq}, results)
       when unknown in ?a..?z or unknown in ?A..?Z do
    decode_next(rest, {:text, ""}, [{:unknown, <<seq::binary, unknown>>} | results])
  end

  # Accumulate escape parameters
  defp decode_next(<<char, rest::binary>>, {:esc, acc}, results) do
    decode_next(rest, {:esc, acc <> <<char>>}, results)
  end

  # Append last bit of text, no remainder
  defp decode_next(<<>>, {:text, ""}, results) do
    {Enum.reverse(results), ""}
  end

  defp decode_next(<<>>, {:text, acc}, results) do
    {Enum.reverse([acc | results]), ""}
  end

  # In the middle of an escape sequence, so there is some remainder
  defp decode_next(<<>>, {:esc, acc}, results) do
    {Enum.reverse(results), acc}
  end

  defp decode_mode(mode) do
    with {code, ""} <- Integer.parse(mode),
         name when name != :invalid <- decode_sequence(code) do
      name
    else
      _ -> :invalid
    end
  end
end
