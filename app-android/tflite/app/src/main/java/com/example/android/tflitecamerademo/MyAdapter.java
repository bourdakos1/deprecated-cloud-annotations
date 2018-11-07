package com.example.android.tflitecamerademo;

import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.util.Log;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ProgressBar;
import android.widget.TextView;

import java.util.List;
import java.util.Locale;
import java.util.Map;

import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.RecyclerView;

/**
 * Created by niko on 11/6/18.
 */

public class MyAdapter extends RecyclerView.Adapter<MyAdapter.MyViewHolder> {
    private List<Map.Entry<String, Float>> mDataset;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    public static class MyViewHolder extends RecyclerView.ViewHolder {
        // each data item is just a string in this case
        public TextView mLabel;
        public TextView mScore;
        public ProgressBar mProgressBar;
        public Drawable mRedDrawable;
        public Drawable mYellowDrawable;
        public Drawable mGreenDrawable;

        public MyViewHolder(View v) {
            super(v);
            mLabel = v.findViewById(R.id.label);
            mScore = v.findViewById(R.id.score);
            mProgressBar = v.findViewById(R.id.progress_bar);
            mRedDrawable = ContextCompat.getDrawable(v.getContext(), R.drawable.red_progress);
            mYellowDrawable = ContextCompat.getDrawable(v.getContext(),R.drawable.yellow_progress);
            mGreenDrawable = ContextCompat.getDrawable(v.getContext(),R.drawable.green_progress);
        }
    }

    // Provide a suitable constructor (depends on the kind of dataset)
    public MyAdapter(List<Map.Entry<String, Float>> myDataset) {
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public MyAdapter.MyViewHolder onCreateViewHolder(ViewGroup parent,
                                                     int viewType) {
        // create a new view
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.classification_item, parent, false);
        return new MyViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(MyViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element

        holder.mLabel.setText(mDataset.get(position).getKey());
        holder.mScore.setText(String.format(Locale.getDefault(), "%1.2f", mDataset.get(position).getValue()));

        if (mDataset.get(position).getValue() <= 0.66666) {
            holder.mProgressBar.setProgressDrawable(holder.mRedDrawable);
        } else if (mDataset.get(position).getValue() <= 0.83333) {
            holder.mProgressBar.setProgressDrawable(holder.mYellowDrawable);
        } else {
            holder.mProgressBar.setProgressDrawable(holder.mGreenDrawable);
        }

        // We need the progress to end up being at least 8dp.
        // 8dp / 107dp * 100 = 7.47663551 ~ 7
        int progress = Math.max(7, (int)(mDataset.get(position).getValue() * 100));
        holder.mProgressBar.setProgress(progress);
    }

    // Return the size of your dataset (invoked by the layout manager)
    @Override
    public int getItemCount() {
        return mDataset.size();
    }
}
