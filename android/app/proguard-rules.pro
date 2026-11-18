# Release builds shrink with R8 (full mode). Rules here keep what is only reached by reflection.

# Room makes each database by reflection: Class.forName("<Db>_Impl").newInstance(). AdMob (play-services-ads) brings
# WorkManager, whose WorkDatabase_Impl lost its no-arg constructor in release and the app crashed at launch
# (NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>). Keep every Room database's constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
