package com.genericclient.scripts.shared;

public final class Supply
{
	public final int id;
	public final String name;
	public final int quantity;
	public final int maximumPrice;
	public final int[] ids;

	public Supply(int id, String name, int quantity, int maximumPrice, int... alternatives)
	{
		this.id = id; this.name = name; this.quantity = quantity; this.maximumPrice = maximumPrice;
		ids = new int[alternatives.length+1];
		ids[0] = id;
		System.arraycopy(alternatives,0,ids,1,alternatives.length);
	}
}
