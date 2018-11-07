/* Copyright 2017 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

package com.example.android.tflitecamerademo;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.text.Layout;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.xlythe.fragment.camera.CameraFragment;
import com.xlythe.view.camera.CameraView;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.AbstractMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.DividerItemDecoration;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import static com.google.android.material.bottomsheet.BottomSheetBehavior.STATE_COLLAPSED;
import static com.google.android.material.bottomsheet.BottomSheetBehavior.STATE_EXPANDED;
import static com.google.android.material.bottomsheet.BottomSheetBehavior.STATE_HIDDEN;

public class Camera2BasicFragment extends CameraFragment {
    private static final String TAG = "CameraFragment";

    private CameraView mCamera;
    private ImageView mResult;
    private LinearLayout mCameraLayout;
    private FrameLayout mImageFrame;
    private ImageClassifier mClassifier;
    private BottomSheetBehavior mBottomSheetBehavior;

    private RecyclerView mRecyclerView;
    private RecyclerView.Adapter mAdapter;
    private RecyclerView.LayoutManager mLayoutManager;

    private View.OnClickListener mBitmapCaptured = new View.OnClickListener() {
        @Override
        public void onClick(View view) {
            try {
                Field field = mCamera.getClass().getDeclaredField("mCameraView");
                field.setAccessible(true);
                TextureView textureView = (TextureView) field.get(mCamera);
                Bitmap bitmap = textureView.getBitmap(ImageClassifier.DIM_IMG_SIZE_X, ImageClassifier.DIM_IMG_SIZE_Y);
                List<Map.Entry<String, Float>> textToShow = mClassifier.classifyFrame(bitmap);
                textToShow.add(new AbstractMap.SimpleEntry<>("Green Progress", 0.84f));
                textToShow.add(new AbstractMap.SimpleEntry<>("Yellow Progress", 0.7f));
                textToShow.add(new AbstractMap.SimpleEntry<>("Red Progress", 0.64f));
                textToShow.add(new AbstractMap.SimpleEntry<>("Really Long Progress That Should Clip and Show Ellipses", 0.21f));
                mAdapter = new MyAdapter(textToShow);
                mRecyclerView.setAdapter(mAdapter);
                mResult.setImageBitmap(bitmap);
                mCameraLayout.setVisibility(View.GONE);
                mImageFrame.setVisibility(View.VISIBLE);
                mBottomSheetBehavior.setHideable(false);
                mBottomSheetBehavior.setState(STATE_EXPANDED);
            } catch (NoSuchFieldException e) {
                e.printStackTrace();
            } catch (IllegalAccessException e) {
                e.printStackTrace();
            }
        }
    };

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        LinearLayout bottomSheet = getActivity().findViewById(R.id.bottom_sheet);
        mBottomSheetBehavior = BottomSheetBehavior.from(bottomSheet);
        mBottomSheetBehavior.setHideable(true);
        mBottomSheetBehavior.setState(STATE_HIDDEN);

        mRecyclerView = bottomSheet.findViewById(R.id.my_recycler_view);
        mRecyclerView.setHasFixedSize(true);
        mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);
        mAdapter = new MyAdapter(new ArrayList<>());
        mRecyclerView.setAdapter(mAdapter);
        DividerItemDecoration divider = new DividerItemDecoration(mRecyclerView.getContext(), DividerItemDecoration.VERTICAL);
        divider.setDrawable(ContextCompat.getDrawable(getContext(), R.drawable.divider));
        mRecyclerView.addItemDecoration(divider);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        mCamera = view.findViewById(R.id.camera);
        mResult = view.findViewById(R.id.image_result);
        mCameraLayout = view.findViewById(R.id.layout_camera);
        mImageFrame = view.findViewById(R.id.image_frame);

        try {
            mClassifier = new ImageClassifier(getContext());
        } catch (IOException e) {
            e.printStackTrace();
        }

        Button button = view.findViewById(R.id.capture_bitmap);
        button.setOnClickListener(mBitmapCaptured);
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return View.inflate(getContext(), R.layout.fragment_camera2_basic, container);
    }

    @Override
    public void onImageCaptured(File file) {}

    @Override
    public void onVideoCaptured(File file) {}

    @Override
    public void onDestroy() {
        mClassifier.close();
        super.onDestroy();
    }
}