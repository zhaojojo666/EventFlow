package com.eventflow.controller;

import cn.hutool.core.util.StrUtil;
import com.eventflow.dto.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("upload")
public class UploadController {
    @Value("${eventflow.upload-dir}")
    private String uploadDir;

    @PostMapping("activity-post")
    public Result uploadImage(@RequestParam("file") MultipartFile image) {
        try {
            // 获取原始文件名称
            String originalFilename = image.getOriginalFilename();
            // 生成新文件名
            String fileName = createNewFileName(originalFilename);
            // 保存文件
            Path destination = Paths.get(uploadDir).toAbsolutePath().normalize()
                    .resolve(fileName.substring(1));
            image.transferTo(destination.toFile());
            // 返回结果
            log.debug("文件上传成功，{}", fileName);
            return Result.ok(fileName);
        } catch (IOException e) {
            throw new RuntimeException("文件上传失败", e);
        }
    }

    @GetMapping("/activity-post/delete")
    public Result deleteActivityPostImg(@RequestParam("name") String filename) {
        if (!filename.startsWith("/imgs/activity-posts/")) {
            return Result.fail("错误的文件名称");
        }
        Path root = Paths.get(uploadDir).toAbsolutePath().normalize();
        Path file = root.resolve(filename.substring("/imgs/".length())).normalize();
        if (!file.startsWith(root.resolve("activity-posts")) || !Files.isRegularFile(file)) {
            return Result.fail("错误的文件名称");
        }
        try {
            Files.delete(file);
        } catch (IOException e) {
            throw new RuntimeException("文件删除失败", e);
        }
        return Result.ok();
    }

    private String createNewFileName(String originalFilename) {
        // 获取后缀
        String suffix = StrUtil.subAfter(originalFilename, ".", true);
        // 生成目录
        String name = UUID.randomUUID().toString();
        int hash = name.hashCode();
        int d1 = hash & 0xF;
        int d2 = (hash >> 4) & 0xF;
        // 判断目录是否存在
        Path dir = Paths.get(uploadDir).toAbsolutePath().normalize()
                .resolve(StrUtil.format("activity-posts/{}/{}", d1, d2));
        try {
            Files.createDirectories(dir);
        } catch (IOException e) {
            throw new RuntimeException("创建上传目录失败", e);
        }
        // 生成文件名
        return StrUtil.format("/activity-posts/{}/{}/{}.{}", d1, d2, name, suffix);
    }
}
