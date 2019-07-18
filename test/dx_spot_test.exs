defmodule DxClusterEx.DxSpotTest do
  use ExUnit.Case
  alias DxClusterEx.DxSpot

  @normal_spot "DX de W3ANX:     28600.0  PJ4DX                                       2208Z\r\n"
  @extended_spot "DX de F5MUX-#:   14038.2  7S5A         CW 18 dB 23 WPM CQ             1346Z\r\n"
  @today "2016-02-29T00:01:30.120+00:00 Etc/Utc"

  test "parses a spot without a note" do
    spot = DxSpot.parse(@normal_spot)
    assert spot.de == "W3ANX"
    assert spot.dx == "PJ4DX"
    assert spot.frequency == 28_600.0
    assert spot.note == ""
  end

  test "parses a spot with a note" do
    spot = DxSpot.parse(@extended_spot)
    assert spot.de == "F5MUX-#"
    assert spot.dx == "7S5A"
    assert spot.frequency == 14_038.2
    assert spot.note == "CW 18 dB 23 WPM CQ"
  end

  test "converts timestamp into datetime" do
    spot = DxSpot.parse(@extended_spot)

    assert Timex.is_valid?(spot.spot_dt) == true
  end

  test "passes the raw packet forward" do
    spot = DxSpot.parse(@extended_spot)

    assert spot.raw == String.trim(@extended_spot)
  end

  test "fixes near-midnight timestamps" do
    {:ok, today} = Timex.parse(@today, "{ISO:Extended}")
    hour = "23"
    min = "59"

    spot_dt =
      today
      |> Timex.set(hour: hour, minute: min, second: 0)
      |> DxSpot.fix_near_midnight(today, hour)

    assert Timex.format!(today, "{D}") == "29"
    assert Timex.format!(spot_dt, "{D}") == "28"
  end
end
