defmodule DxClusterEx.DxSpot do
  @dx_spot_match ~r/DX de (.+):\s+([0-9.]+)\s+([^\s]+)\s+?(.*)\s+([0-9]{2}[0-9]{2})Z\s*(([A-Z]{2}[0-9]{2})*)/

  def parse(packet) do
    dx_spot =
      @dx_spot_match
      |> Regex.run(packet)
      |> Enum.map(&String.trim/1)

    [:raw, :de, :frequency, :dx, :note, :spot_dt, :grid]
    |> Enum.zip(dx_spot)
    |> Enum.into(%{})
    |> Map.update(:frequency, 0.0, fn freq_str ->
      {frequency, ""} = Float.parse(freq_str)
      frequency
    end)
    |> Map.update(:spot_dt, "0000", fn spot_time ->
      calculate_time(Timex.now(), spot_time)
    end)
  end

  def calculate_time(current, spot_time) do
    {hour, min} = String.split_at(spot_time, 2)

    current
    |> Timex.set(hour: hour, minute: min, second: 0)
    |> fix_near_midnight(current, hour)
  end

  def fix_near_midnight(spot_dt, %DateTime{hour: 0}, "23"), do: Timex.shift(spot_dt, days: -1)

  def fix_near_midnight(spot_dt, _current_dt, _spot_hour), do: spot_dt
end
